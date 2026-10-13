// deno test supabase/functions/send-push/lib_test.ts
import {
  base64UrlEncode,
  buildFcmMessage,
  fcmErrorCode,
  isUnregistered,
  parseServiceAccount,
  pemToDer,
  signServiceAccountJwt,
  timingSafeEqual,
} from "./lib.ts";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

function b64urlToBytes(s: string) {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const raw = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

Deno.test("RS256 JWT: başlık, iddialar ve imza doğrulanır", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let b64 = btoa(String.fromCharCode(...pkcs8));
  b64 = b64.replace(/(.{64})/g, "$1\n");
  // Gizli değişkende sık görülen biçim: satır sonları "\n" kaçışı olarak.
  const pem = `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`
    .replace(/\n/g, "\\n");

  const account = parseServiceAccount(JSON.stringify({
    client_email: "svc@proje.iam.gserviceaccount.com",
    private_key: pem,
    project_id: "proje",
  }));
  assert(account.token_uri === "https://oauth2.googleapis.com/token", "varsayılan token_uri");

  const jwt = await signServiceAccountJwt(account, "scope-x", 1_000_000);
  const [h, p, s] = jwt.split(".");
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h)));
  const claims = JSON.parse(new TextDecoder().decode(b64urlToBytes(p)));
  assert(header.alg === "RS256" && header.typ === "JWT", "başlık");
  assert(claims.iss === account.client_email && claims.scope === "scope-x", "iss/scope");
  assert(claims.aud === account.token_uri, "aud");
  assert(claims.iat === 1_000_000 && claims.exp === 1_003_600, "iat/exp");
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pair.publicKey,
    b64urlToBytes(s),
    new TextEncoder().encode(`${h}.${p}`),
  );
  assert(ok, "imza doğrulanamadı");
});

Deno.test("servis hesabı eksik alanı adıyla bildirir, değeri sızdırmaz", () => {
  let message = "";
  try {
    parseServiceAccount(JSON.stringify({ client_email: "a@b", project_id: "p" }));
  } catch (e) {
    message = (e as Error).message;
  }
  assert(message === "service_account_missing:private_key", message);
  let notJson = "";
  try {
    parseServiceAccount("{gizli");
  } catch (e) {
    notJson = (e as Error).message;
  }
  assert(notJson === "service_account_not_json", notJson);
});

Deno.test("FCM iletisi python betiğiyle aynı biçimde", () => {
  const job = {
    job_id: "j",
    to_user_id: "u",
    kind: "async_duel_invite",
    title: "ZanKurd",
    body: "metin",
    fcm_token: "t",
  };
  const m = buildFcmMessage(job, "t").message as Record<string, unknown>;
  assert(m.token === "t", "token");
  assert(
    JSON.stringify(m.notification) === JSON.stringify({ title: "ZanKurd", body: "metin" }),
    "notification",
  );
  assert(JSON.stringify(m.data) === JSON.stringify({ kind: "async_duel_invite" }), "data.kind");
  const noKind = buildFcmMessage({ ...job, kind: null, title: null, body: null }, "t")
    .message as Record<string, unknown>;
  assert(!("data" in noKind), "kind yokken data olmamalı");
  assert((noKind.notification as { title: string }).title === "ZanKurd", "başlık yedeği");
});

Deno.test("UNREGISTERED sınıflaması", () => {
  assert(isUnregistered(404, null), "404");
  assert(isUnregistered(400, { error: { status: "NOT_FOUND" } }), "NOT_FOUND");
  assert(
    isUnregistered(400, {
      error: { status: "X", details: [{ errorCode: "UNREGISTERED" }] },
    }),
    "details",
  );
  assert(!isUnregistered(400, { error: { status: "INVALID_ARGUMENT" } }), "INVALID_ARGUMENT");
  assert(!isUnregistered(500, null), "500");
  assert(fcmErrorCode({ error: { status: "UNAVAILABLE" } }) === "UNAVAILABLE", "kod");
  assert(fcmErrorCode(null) === "unknown", "kod yok");
});

Deno.test("timingSafeEqual ve base64url/pem yardımcıları", () => {
  assert(timingSafeEqual("abc", "abc"), "eşit");
  assert(!timingSafeEqual("abc", "abd"), "farklı");
  assert(!timingSafeEqual("abc", "abcd"), "uzunluk");
  assert(!timingSafeEqual("", "x"), "boş");
  assert(base64UrlEncode(new Uint8Array([251, 255])) === "-_8", "base64url");
  const der = pemToDer("-----BEGIN X-----\\nAQID\\n-----END X-----");
  assert(der.length === 3 && der[0] === 1 && der[2] === 3, "pem");
});
