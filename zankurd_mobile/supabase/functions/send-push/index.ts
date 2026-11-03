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
//   3. `claim_push_outbox_v2` en çok 20 işi 120 saniyelik lease ile verir.
//      Eski kalıcı claim RPC'sine fallback YOK; SQL sözleşmesi önce kurulmalı.
//      2026-11-04: tek paketle çıkılmaz; kuyruk boşalana ya da ~25 sn talep
//      bütçesi dolana dek paket paket talep edilir (`shouldClaimNextBatch`).
//   4. En çok 5 eşzamanlı FCM çağrısı, her biri 10 sn zaman aşımı.
//      `finish_push_outbox` lease kimliğiyle başarı/kalıcı hata/retry kaydeder.
//      Süreç ölürse lease zaman aşımı işi yeniden alınabilir kılar.
//      FCM kabulü ile DB ack'i atomik değildir; çok nadir tekrar mümkündür.
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
  deliverPushJob,
  parseServiceAccount,
  type PushJob,
  type ServiceAccount,
  shouldClaimNextBatch,
  signServiceAccountJwt,
  timingSafeEqual,
  validPushExpiry,
} from "./lib.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const BATCH_LIMIT = 20;
const CONCURRENCY = 5;
const REQUEST_TIMEOUT_MS = 10_000;
// Yeni paket TALEP etme bütçesi. Paket başına işleme (55 sn başlangıç sınırı)
// ve ack payı bunun ÜSTÜNE biner; lease 120 sn olduğundan talep edilen paket
// her zaman lease dolmadan işlenir.
const CLAIM_BUDGET_MS = 25_000;

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
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
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
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const expected = Deno.env.get("CRON_SECRET") ?? "";
  if (!expected) return json({ error: "server_misconfigured" }, 500);
  const presented = request.headers.get("x-cron-secret") ?? "";
  if (!timingSafeEqual(presented, expected)) {
    return json({ error: "unauthorized" }, 401);
  }

  let account: ServiceAccount;
  let admin: SupabaseClient;
  try {
    account = parseServiceAccount(requiredEnv("FCM_SERVICE_ACCOUNT_JSON"));
    admin = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false, autoRefreshToken: false },
        global: {
          fetch: (input, init) =>
            fetch(input, {
              ...init,
              signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
            }),
        },
      },
    );
  } catch (error) {
    console.error(
      "send-push misconfigured",
      error instanceof Error ? error.message : "unknown",
    );
    return json({ error: "server_misconfigured" }, 500);
  }

  let bearer: string;
  try {
    bearer = await accessToken(account);
  } catch (error) {
    // Kuyruğa henüz dokunulmadı: bir sonraki çalıştırma yeniden dener.
    console.error(
      "send-push oauth",
      error instanceof Error ? error.message : "unknown",
    );
    return json({ error: "oauth_failed" }, 502);
  }

  const counts = {
    claimed: 0,
    sent: 0,
    skipped: 0,
    failed: 0,
    retry: 0,
    unsettled: 0,
    cleared: 0,
    batches: 0,
  };
  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;
  const claimDeadline = Date.now() + CLAIM_BUDGET_MS;
  let lastClaimed: number | null = null;

  while (
    shouldClaimNextBatch({
      now: Date.now(),
      deadline: claimDeadline,
      lastClaimed,
      unsettled: counts.unsettled,
      batches: counts.batches,
    })
  ) {
    let data: unknown;
    try {
      const result = await admin.rpc("claim_push_outbox_v2", {
        p_limit: BATCH_LIMIT,
      });
      if (result.error) {
        console.error("claim_push_outbox_v2 failed", result.error.code);
        // Önceki paketler işlendi; yalnız bu talep başarısız.
        if (counts.batches === 0) return json({ error: "claim_failed" }, 500);
        break;
      }
      data = result.data;
    } catch (_) {
      if (counts.batches === 0) return json({ error: "claim_failed" }, 500);
      break;
    }
    // Uyumsuz RPC yanıtında FCM'ye dokunma; lease sona erince güvenle yeniden alınır.
    if (
      !Array.isArray(data) || data.some((job) =>
        !job ||
        typeof job.job_id !== "string" || !job.job_id ||
        typeof job.claim_token !== "string" || !job.claim_token ||
        !Number.isInteger(job.attempt_count) || job.attempt_count < 1 ||
        !validPushExpiry(job.expires_at)
      )
    ) {
      return json({ error: "invalid_claim_contract" }, 500);
    }
    const jobs = data as PushJob[];
    lastClaimed = jobs.length;
    if (jobs.length === 0) break;
    counts.batches++;
    counts.claimed += jobs.length;
    let next = 0;
    // Claim10sn + FCM10sn + token temizleme10sn + ack30sn için lease payı.
    const startDeadline = Date.now() + 55_000;
    async function worker() {
      while (next < jobs.length) {
        if (Date.now() >= startDeadline) {
          counts.unsettled += jobs.length - next;
          next = jobs.length;
          return; // Kalan işler lease bitince yeniden alınır; FCM gönderilmez.
        }
        const job = jobs[next++];
        const outcome = await deliverPushJob(job, {
          send: async (_job, _token, payload) => {
            const response = await fetch(fcmUrl, {
              signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
              method: "POST",
              headers: {
                Authorization: `Bearer ${bearer}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(payload),
            });
            // Sonraki invocation OAuth'u yenilesin;401 retry sayısı SQL'de8 ile sınırlı.
            if (response.status === 401) cachedToken = null;
            return response;
          },
          finish: async (_job, completion) => {
            const result = await admin.rpc("finish_push_outbox", {
              p_job_id: _job.job_id,
              p_claim_token: _job.claim_token,
              p_outcome: completion.outcome,
              p_error_code: completion.errorCode ?? null,
              p_retry_after_seconds: completion.retryAfterSeconds ?? null,
            });
            if (result.error) {
              console.error(
                "finish_push_outbox failed",
                _job.job_id,
                result.error.code,
              );
            }
            return !result.error && result.data === true;
          },
          clearToken: async (_job, token) => {
            const result = await admin.rpc("clear_fcm_token", {
              p_user_id: _job.to_user_id,
              p_token: token,
            });
            if (result.error) {
              console.error("clear_fcm_token failed", result.error.code);
            } else counts.cleared++;
            return !result.error;
          },
        });
        counts[outcome]++;
        if (outcome === "unsettled") {
          console.error("push acknowledgement unsettled", job.job_id);
        }
      }
    }
    await Promise.all(
      Array.from({ length: Math.min(CONCURRENCY, jobs.length) }, worker),
    );
  }
  return json(counts, counts.unsettled > 0 ? 502 : 200);
});
