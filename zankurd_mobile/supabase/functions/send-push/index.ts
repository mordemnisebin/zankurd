// send-push — push_outbox kuyruğunu FCM HTTP v1 ile gönderir.
//
// NİÇİN: kuyruğa yazan SQL tarafı (2026-08-26_fcm_token.sql, düello sonucu,
// düello daveti) hazırdı ama gerçek teslimat yalnız elle çalıştırılan
// `tool/send_push_outbox.py` betiğindeydi; hiçbir şey onu çalıştırmıyordu, yani
// hiçbir bildirim ulaşmıyordu. Bu fonksiyon aynı işi sunucuda yapar; pg_cron
// her dakika `pg_net` ile çağırır (bkz. supabase/2026-10-13_push_delivery.sql).
// Betik elle yedek olarak kalır.
//
// AKIŞ
//   1. İstek `x-cron-secret` başlığında CRON_SECRET'i sunmalı (JWT DEĞİL;
//      config.toml'da bu fonksiyon için verify_jwt = false). Yoksa 401.
//   2. Google OAuth erişim jetonu (firebase.messaging kapsamı) ÖNCE alınır,
//      kuyruk SONRA talep edilir: jeton alınamazsa satırlar "claimed"
//      işaretlenmeden kalır, bir sonraki dakika yeniden denenir.
//   3. `claim_push_outbox(p_limit => 50)` (service_role) satırları işaretleyip
//      hedef jetonlarla döndürür. Satır bir kez talep edilir: FCM hatası
//      alan ileti YENİDEN DENENMEZ (sonsuz döngü ve çift bildirim olmasın).
//   4. Her iş için FCM `messages:send`. Jeton yoksa atlanır. FCM 404 /
//      UNREGISTERED ise `clear_fcm_token` ile o kullanıcının jetonu temizlenir.
//
// ORTAM (kodda DEĞER YOK; `supabase secrets set` ile verilir):
//   FCM_SERVICE_ACCOUNT_JSON  Firebase servis hesabı JSON'unun TÜM metni
//   CRON_SECRET               pg_cron çağrısıyla paylaşılan rastgele dize
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: platform tarafından otomatik.
//
// Günlüğe jeton, gizli değer, ileti metni ASLA yazılmaz; yalnız iş kimliği ve
// hata kodu.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildFcmMessage,
  fcmErrorCode,
  isUnregistered,
  parseServiceAccount,
  type PushJob,
  type ServiceAccount,
  signServiceAccountJwt,
  timingSafeEqual,
} from "./lib.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const BATCH_LIMIT = 50;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-cron-secret, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing_env:${name}`);
  return value;
}

// Sıcak örnekte erişim jetonu süresi dolana kadar yeniden kullanılır.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt - 60_000 > now) {
    return cachedToken.value;
  }
  const assertion = await signServiceAccountJwt(account, FCM_SCOPE);
  const response = await fetch(account.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }).toString(),
  });
  if (!response.ok) {
    let code = "unknown";
    try {
      const body = await response.json();
      if (typeof body?.error === "string") code = body.error;
    } catch (_) {
      // gövde yok
    }
    throw new Error(`oauth_failed:${response.status}:${code}`);
  }
  const body = await response.json();
  if (typeof body.access_token !== "string" || !body.access_token) {
    throw new Error("oauth_no_access_token");
  }
  const lifetime = typeof body.expires_in === "number" ? body.expires_in : 3600;
  cachedToken = { value: body.access_token, expiresAt: now + lifetime * 1000 };
  return body.access_token;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("CRON_SECRET") ?? "";
  if (!expected) return json({ error: "server_misconfigured" }, 500);
  const presented = request.headers.get("x-cron-secret") ?? "";
  if (!timingSafeEqual(presented, expected)) return json({ error: "unauthorized" }, 401);

  let account: ServiceAccount;
  let admin: SupabaseClient;
  try {
    account = parseServiceAccount(requiredEnv("FCM_SERVICE_ACCOUNT_JSON"));
    admin = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  } catch (error) {
    console.error("send-push misconfigured", error instanceof Error ? error.message : "unknown");
    return json({ error: "server_misconfigured" }, 500);
  }

  let bearer: string;
  try {
    bearer = await accessToken(account);
  } catch (error) {
    // Kuyruğa henüz dokunulmadı: bir sonraki çalıştırma yeniden dener.
    console.error("send-push oauth", error instanceof Error ? error.message : "unknown");
    return json({ error: "oauth_failed" }, 502);
  }

  const { data, error: claimError } = await admin.rpc("claim_push_outbox", {
    p_limit: BATCH_LIMIT,
  });
  if (claimError) {
    console.error("claim_push_outbox failed", claimError.code);
    return json({ error: "claim_failed" }, 500);
  }
  const jobs = (data ?? []) as PushJob[];
  if (jobs.length === 0) return json({ claimed: 0, sent: 0, skipped: 0, failed: 0, cleared: 0 });

  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;
  let sent = 0;
  let skipped = 0;
  let failed = 0;
  let cleared = 0;

  for (const job of jobs) {
    const token = job.fcm_token;
    if (!token) {
      skipped++;
      continue;
    }
    try {
      const response = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${bearer}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(buildFcmMessage(job, token)),
      });
      if (response.ok) {
        await response.body?.cancel();
        sent++;
        continue;
      }
      let body: unknown = null;
      try {
        body = await response.json();
      } catch (_) {
        // gövde yok
      }
      failed++;
      console.error("fcm send failed", job.job_id, response.status, fcmErrorCode(body));
      if (isUnregistered(response.status, body)) {
        const { error } = await admin.rpc("clear_fcm_token", {
          p_user_id: job.to_user_id,
          p_token: token,
        });
        if (error) console.error("clear_fcm_token failed", error.code);
        else cleared++;
      }
    } catch (error) {
      failed++;
      console.error("fcm send error", job.job_id, error instanceof Error ? error.name : "unknown");
    }
  }

  return json({ claimed: jobs.length, sent, skipped, failed, cleared });
});
