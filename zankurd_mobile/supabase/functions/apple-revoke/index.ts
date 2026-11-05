// apple-revoke — "Sign in with Apple" jetonunu hesap silinirken iptal eder.
//
// NİÇİN (App Store Review Guideline 5.1.1(v)): Apple ile giriş sunan bir
// uygulama hesabı silerken kullanıcının Apple tarafındaki bağlantısını da
// iptal etmelidir (Apple REST: POST /auth/revoke). Aksi hâlde kullanıcı
// "Apple ID ile giriş yapan uygulamalar" listesinde silinmiş bir hesabı
// görmeye devam eder.
//
// AKIŞ
//   1. `register` — Apple ile girişten HEMEN SONRA istemci, Apple'ın verdiği
//      `authorizationCode`u gönderir. Kod tek kullanımlık ve ~5 dakikalıktır;
//      bu yüzden silme anına kadar saklanamaz. Fonksiyon kodu Apple'a
//      `/auth/token` ile takas edip dönen `refresh_token`ı
//      `public.apple_auth_tokens` tablosuna (istemciye kapalı) yazar.
//   2. `revoke` — hesap silinirken, `delete_my_account` ÇAĞRILMADAN önce.
//      Saklı refresh_token `/auth/revoke` ile iptal edilir ve satır silinir.
//      Saklı jeton yoksa ve istekte `authorization_code` varsa (girişten
//      hemen sonra silme) önce takas edilip sonra iptal edilir.
//
// Her iki çağrı da kullanıcının Supabase JWT'siyle yapılır; yalnız KENDİ
// jetonu üzerinde işlem yapılır (satır anahtarı JWT'den doğrulanan user.id;
// istek gövdesinden kullanıcı kimliği alınmaz). Apple jetonu olmayan hesapta
// `no_token` döner, zarar vermez.
//
// ORTAM (kodda DEĞER YOK; `supabase secrets set` ile verilir):
//   APPLE_TEAM_ID      Apple Developer Team ID (10 karakter)
//   APPLE_KEY_ID       "Sign in with Apple" anahtarının Key ID'si
//   APPLE_PRIVATE_KEY  O anahtarın .p8 dosyasının TÜM metni (PEM)
//   APPLE_CLIENT_ID    Yerel iOS girişinde uygulamanın Bundle ID'si
//                      (com.zankurd.app); Services ID DEĞİL.
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: platform tarafından otomatik.
//
// Hata ayıklama günlüğüne jeton, kod ya da anahtar ASLA yazılmaz.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  appleSubjectMatches,
  appleSubjectOf,
  hasAppleIdentity,
  registerRecentlyDone,
  revokeFailureBody,
  revokeOutcome,
  timingSafeEqual,
} from "./lib.ts";

// 2026-11-16 (W4, GPT-6 Pro ALAN 4 #1 #3 #16): DEĞİŞENLER
//  - `register`/`revoke` kodu takas ederken Apple'ın `id_token.sub`ı oturumdaki
//    kullanıcının Apple kimliğinin `sub`ıyla eşleşmezse 403 `apple_subject_mismatch`
//    döner ve hiçbir şey saklanmaz (başka Apple hesabının kodu bu kullanıcının
//    altında saklanıp yanlış hesap iptal edilemez).
//  - İptal başarısızsa jeton SİLİNMEZ. `apple_auth_tokens.user_id` FK'si
//    2026-11-16 göçüyle kalktığı için hesap silinse de satır kalır ("yetim") ve
//    `sweep` eylemi (cron, `x-cron-secret`) yetimleri yeniden dener; başarıda
//    satır silinir. Jeton yalnız Apple iptali başarılı olunca yok edilir.
//  - Yanıtlar: iptal edildi → `revoked: true`; saklı jeton yok → `revoked: false`
//    ve no_token nedeni (istemci bunu BAŞARI saymaz); Apple hatası → 502
//    `revoke_failed` + `queued: true` (jeton kuyrukta kalır).

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  // Gizli değişken tek satıra sıkıştırıldıysa "\n" kaçışları gerçek satıra çevrilir.
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

/// Apple'ın istediği ES256 imzalı `client_secret` JWT'si (5 dk ömürlü).
async function appleClientSecret(): Promise<string> {
  const teamId = requiredEnv("APPLE_TEAM_ID");
  const keyId = requiredEnv("APPLE_KEY_ID");
  const clientId = requiredEnv("APPLE_CLIENT_ID");
  const privateKey = requiredEnv("APPLE_PRIVATE_KEY");

  const now = Math.floor(Date.now() / 1000);
  const enc = new TextEncoder();
  const header = base64UrlEncode(
    enc.encode(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" })),
  );
  const payload = base64UrlEncode(
    enc.encode(
      JSON.stringify({
        iss: teamId,
        iat: now,
        exp: now + 300,
        aud: "https://appleid.apple.com",
        sub: clientId,
      }),
    ),
  );
  const signingInput = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // WebCrypto ECDSA imzası zaten JWT'nin istediği ham r||s biçimindedir.
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      enc.encode(signingInput),
    ),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

async function appleForm(
  url: string,
  fields: Record<string, string>,
): Promise<{ status: number; body: Record<string, unknown> }> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(fields).toString(),
  });
  let body: Record<string, unknown> = {};
  try {
    body = await response.json();
  } catch (_) {
    // /auth/revoke başarıda boş gövde döner.
  }
  return { status: response.status, body };
}

/// Yetkilendirme kodunu Apple'a takas eder; refresh_token ve id_token döner.
async function exchangeCode(
  code: string,
): Promise<{ refresh: string; idToken: unknown } | null> {
  const result = await appleForm(APPLE_TOKEN_URL, {
    client_id: requiredEnv("APPLE_CLIENT_ID"),
    client_secret: await appleClientSecret(),
    code,
    grant_type: "authorization_code",
  });
  if (result.status !== 200) {
    console.error("apple /auth/token failed", result.status, result.body.error);
    return null;
  }
  const refresh = result.body.refresh_token;
  return typeof refresh === "string" && refresh.length > 0
    ? { refresh, idToken: result.body.id_token }
    : null;
}

/// Refresh token'ı Apple'da iptal eder: true = amaç gerçekleşti.
async function revokeAtApple(refreshToken: string): Promise<boolean> {
  const result = await appleForm(APPLE_REVOKE_URL, {
    client_id: requiredEnv("APPLE_CLIENT_ID"),
    client_secret: await appleClientSecret(),
    token: refreshToken,
    token_type_hint: "refresh_token",
  });
  const outcome = revokeOutcome(result.status, result.body.error);
  if (outcome === "failed") {
    console.error("apple /auth/revoke failed", result.status, result.body.error);
  }
  return outcome === "revoked";
}

/// Hesabı silinmiş kullanıcıların (user_id artık auth.users'ta yok) iptal
/// edilememiş jetonlarını yeniden dener. Başarıda satır silinir.
async function sweepOrphans(
  admin: SupabaseClient,
  limit: number,
): Promise<{ checked: number; revoked: number; failed: number }> {
  const out = { checked: 0, revoked: 0, failed: 0 };
  const { data, error } = await admin.rpc("apple_orphan_tokens", { p_limit: limit });
  if (error) {
    console.error("apple_orphan_tokens failed", error.code);
    throw new Error("orphan_list_failed");
  }
  for (const row of (data ?? []) as Array<{ user_id: string; refresh_token: string }>) {
    out.checked++;
    let ok = false;
    try {
      ok = await revokeAtApple(row.refresh_token);
    } catch (_) {
      ok = false;
    }
    if (ok) {
      const { error: delError } = await admin.from("apple_auth_tokens")
        .delete().eq("user_id", row.user_id);
      if (delError) console.error("orphan delete failed", delError.code);
      out.revoked++;
    } else {
      out.failed++;
      const { error: upError } = await admin.rpc("apple_orphan_failed", {
        p_user_id: row.user_id,
      });
      if (upError) console.error("apple_orphan_failed rpc", upError.code);
    }
  }
  return out;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // cron: yetim jeton yeniden denemesi (JWT DEĞİL, paylaşılan sır).
  const cronSecret = request.headers.get("x-cron-secret");
  if (cronSecret !== null) {
    const expected = Deno.env.get("CRON_SECRET") ?? "";
    if (!expected) return json({ error: "server_misconfigured" }, 500);
    if (!timingSafeEqual(cronSecret, expected)) return json({ error: "unauthorized" }, 401);
    try {
      const adminCron = createClient(
        requiredEnv("SUPABASE_URL"),
        requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
        { auth: { persistSession: false, autoRefreshToken: false } },
      );
      const counts = await sweepOrphans(adminCron, 20);
      console.log("apple-revoke sweep", counts);
      return json(counts, counts.failed > 0 ? 502 : 200);
    } catch (error) {
      console.error("apple-revoke sweep error", error instanceof Error ? error.message : "unknown");
      return json({ error: "sweep_failed" }, 500);
    }
  }

  const jwt = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "unauthenticated" }, 401);

  let admin: SupabaseClient;
  try {
    admin = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  } catch (_) {
    return json({ error: "server_misconfigured" }, 500);
  }

  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userError || !user) return json({ error: "unauthenticated" }, 401);

  let body: { action?: string; authorization_code?: string } = {};
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "invalid_json" }, 400);
  }

  try {
    if (body.action === "register") {
      const code = body.authorization_code?.trim();
      if (!code) return json({ error: "authorization_code_required" }, 400);
      // GPT-6 Pro ALAN 4: Apple kimliği olmayan (misafir / e-posta) oturum
      // özel anahtarla JWT imzalatıp Apple token takasını başlatamaz.
      if (!hasAppleIdentity(user)) {
        return json({ registered: false, error: "apple_identity_required" }, 403);
      }
      // Aynı kullanıcının kısa aralıkla tekrarlanan kaydı aynı işte birleşir
      // (istemci yeniden denemesi, çift dokunuş, saldırı): Apple'a gitmeden
      // saklı jeton "kayıtlı" sayılır. Eski (build 43) istemciler yalnız
      // `registered` alanına bakar; yanıt biçimi aynıdır.
      const { data: recent, error: recentError } = await admin
        .from("apple_auth_tokens")
        .select("updated_at")
        .eq("user_id", user.id)
        .maybeSingle();
      if (recentError) {
        console.error("apple_auth_tokens recent read failed", recentError.code);
        return json({ registered: false, error: "store_failed" }, 500);
      }
      if (registerRecentlyDone(
          (recent as { updated_at?: string } | null)?.updated_at,
          Date.now(),
        )) {
        return json({ registered: true, coalesced: true });
      }
      const exchanged = await exchangeCode(code);
      if (!exchanged) return json({ registered: false, error: "exchange_failed" }, 502);
      // #16: kod bu kullanıcının Apple hesabına mı ait? Değilse saklanmaz.
      if (!appleSubjectMatches(exchanged.idToken, appleSubjectOf(user))) {
        console.error("apple register: subject mismatch or unknown");
        return json({ registered: false, error: "apple_subject_mismatch" }, 403);
      }
      const { error } = await admin.from("apple_auth_tokens").upsert({
        user_id: user.id,
        refresh_token: exchanged.refresh,
        updated_at: new Date().toISOString(),
      });
      if (error) {
        console.error("apple_auth_tokens upsert failed", error.code);
        return json({ registered: false, error: "store_failed" }, 500);
      }
      return json({ registered: true });
    }

    if (body.action === "revoke") {
      const { data: row, error: readError } = await admin
        .from("apple_auth_tokens")
        .select("refresh_token")
        .eq("user_id", user.id)
        .maybeSingle();
      // Okuma hatası "jeton yok" değildir: yanlışlıkla 200 `no_token` dönmek
      // istemciyi "iptal edecek bir şey yok" sanmaya iter. 5xx dönülür; istemci
      // yine kullanıcının silme hakkını bloklamaz ama sonucu doğru (başarısız)
      // görür ve kaydeder.
      if (readError) {
        console.error("apple_auth_tokens read failed", readError.code);
        return json({ revoked: false, error: "token_read_failed" }, 500);
      }

      let refreshToken: string | null = row?.refresh_token ?? null;
      const code = body.authorization_code?.trim();
      // Satırdan okunan jeton zaten kalıcıdır; takas edilen ancak yazılınca kalıcı olur.
      let tokenSaved = refreshToken !== null;
      if (!refreshToken && code) {
        // Girişten hemen sonra silme: kod henüz saklanmamış. #16: sahibi bu
        // kullanıcı değilse reddedilir; geçerliyse jeton ÖNCE saklanır, iptal
        // başarısız olursa yetim kuyruğunda yeniden denenir.
        const exchanged = await exchangeCode(code);
        if (exchanged) {
          if (!appleSubjectMatches(exchanged.idToken, appleSubjectOf(user))) {
            console.error("apple revoke: subject mismatch or unknown");
            return json({ revoked: false, error: "apple_subject_mismatch" }, 403);
          }
          refreshToken = exchanged.refresh;
          // Jeton kalıcı saklanmadıkça "kuyrukta" denemez: yazım bir kez yeniden denenir.
          for (let attempt = 0; attempt < 2 && !tokenSaved; attempt++) {
            const { error: saveError } = await admin.from("apple_auth_tokens").upsert({
              user_id: user.id,
              refresh_token: refreshToken,
              updated_at: new Date().toISOString(),
            });
            if (saveError) console.error("apple_auth_tokens upsert failed", saveError.code);
            else tokenSaved = true;
          }
        }
      }
      if (!refreshToken) return json({ revoked: false, reason: "no_token" });

      // 200 ya da `invalid_grant` (zaten geçersiz) = amaç gerçekleşti, satır
      // silinir. Başarısızlıkta satır KALIR: hesap silinse bile (FK yok) yetim
      // olarak cron tarafından yeniden denenir.
      if (!(await revokeAtApple(refreshToken))) {
        // Jeton kalıcı değilse süpürücünün yeniden deneyeceği kayıt YOK: `queued`
        // denmez; istemci hesap silmeyi durdurup "tekrar dene" göstermeli (kod hâlâ
        // geçerliyse yeniden takas edilir).
        return json(revokeFailureBody(tokenSaved), 502);
      }
      const { error: deleteError } = await admin
        .from("apple_auth_tokens")
        .delete()
        .eq("user_id", user.id);
      if (deleteError) {
        console.error("apple_auth_tokens delete failed", deleteError.code);
      }
      return json({ revoked: true });
    }

    return json({ error: "unknown_action" }, 400);
  } catch (error) {
    // Ayrıntı (gizli adı dahil) istemciye sızdırılmaz.
    console.error("apple-revoke error", error instanceof Error ? error.message : "unknown");
    return json({ error: "internal" }, 500);
  }
});
