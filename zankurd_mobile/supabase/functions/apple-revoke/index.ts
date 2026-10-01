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

import { createClient } from "npm:@supabase/supabase-js@2";

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

/// Yetkilendirme kodunu Apple'a takas eder; refresh_token döner.
async function exchangeCode(code: string): Promise<string | null> {
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
  return typeof refresh === "string" && refresh.length > 0 ? refresh : null;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const jwt = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "unauthenticated" }, 401);

  let admin: ReturnType<typeof createClient>;
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
      const refreshToken = await exchangeCode(code);
      if (!refreshToken) return json({ registered: false, error: "exchange_failed" }, 502);
      const { error } = await admin.from("apple_auth_tokens").upsert({
        user_id: user.id,
        refresh_token: refreshToken,
        updated_at: new Date().toISOString(),
      });
      if (error) {
        console.error("apple_auth_tokens upsert failed", error.code);
        return json({ registered: false, error: "store_failed" }, 500);
      }
      return json({ registered: true });
    }

    if (body.action === "revoke") {
      const { data: row } = await admin
        .from("apple_auth_tokens")
        .select("refresh_token")
        .eq("user_id", user.id)
        .maybeSingle();

      let refreshToken: string | null = row?.refresh_token ?? null;
      if (!refreshToken && body.authorization_code?.trim()) {
        refreshToken = await exchangeCode(body.authorization_code.trim());
      }
      if (!refreshToken) return json({ revoked: false, reason: "no_token" });

      const result = await appleForm(APPLE_REVOKE_URL, {
        client_id: requiredEnv("APPLE_CLIENT_ID"),
        client_secret: await appleClientSecret(),
        token: refreshToken,
        token_type_hint: "refresh_token",
      });
      // 200 = iptal edildi. `invalid_grant` = jeton zaten geçersiz/iptal
      // (kullanıcı Apple ayarlarından kendisi kaldırmış olabilir): amaç
      // gerçekleşmiş sayılır, satır silinir.
      const alreadyGone = result.status === 400 && result.body.error === "invalid_grant";
      if (result.status !== 200 && !alreadyGone) {
        console.error("apple /auth/revoke failed", result.status, result.body.error);
        return json({ revoked: false, error: "revoke_failed" }, 502);
      }
      await admin.from("apple_auth_tokens").delete().eq("user_id", user.id);
      return json({ revoked: true });
    }

    return json({ error: "unknown_action" }, 400);
  } catch (error) {
    // Ayrıntı (gizli adı dahil) istemciye sızdırılmaz.
    console.error("apple-revoke error", error instanceof Error ? error.message : "unknown");
    return json({ error: "internal" }, 500);
  }
});
