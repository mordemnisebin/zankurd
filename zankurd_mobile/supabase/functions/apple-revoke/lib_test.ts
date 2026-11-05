// apple-revoke yardımcıları — Deno testi (`deno test supabase/functions/apple-revoke/`).
//
// Kusur (GPT-6 Pro ALAN 4): misafir oturum `register` ile özel anahtarla JWT
// imzalatıp Apple token takasını başlatabiliyor, tekrarlar birleşmiyordu.
// Niçin sessiz: fonksiyon geçerli Supabase kullanıcısı yeterli sayıyordu.
import {
  appleSubjectMatches,
  appleSubjectOf,
  decodeJwtPayload,
  hasAppleIdentity,
  registerRecentlyDone,
  revokeFailureBody,
  revokeOutcome,
  timingSafeEqual,
} from "./lib.ts";

function assert(c: boolean, m: string) {
  if (!c) throw new Error(m);
}

Deno.test("Apple kimliği: identities ya da app_metadata", () => {
  assert(hasAppleIdentity({ identities: [{ provider: "apple" }] }), "identities");
  assert(hasAppleIdentity({ app_metadata: { provider: "apple" } }), "provider");
  assert(hasAppleIdentity({ app_metadata: { providers: ["email", "apple"] } }), "providers");
  assert(!hasAppleIdentity({ identities: [{ provider: "google" }] }), "google");
  assert(!hasAppleIdentity({ identities: [], app_metadata: { provider: "anonymous" } }), "misafir");
  assert(!hasAppleIdentity({}), "boş");
});

Deno.test("kısa aralıklı tekrar kayıt birleşir, eski kayıt birleşmez", () => {
  const now = Date.parse("2026-11-06T12:00:00Z");
  assert(registerRecentlyDone("2026-11-06T11:59:45Z", now), "15 sn");
  assert(!registerRecentlyDone("2026-11-06T11:59:00Z", now), "60 sn");
  assert(!registerRecentlyDone(undefined, now), "kayıt yok");
  assert(!registerRecentlyDone("bozuk", now), "bozuk tarih");
  assert(!registerRecentlyDone("2026-11-06T12:05:00Z", now), "gelecek tarih birleşmez");
});

// ── 2026-11-16 (W4, GPT-6 Pro ALAN 4 #1 #3 #16) ─────────────────────────────
// Kusur #16: Apple'ın kodu hangi Apple hesabına ait? Edge `id_token.sub`ı hiç
// okumuyordu; başka bir Apple hesabının kodu bu kullanıcının altında saklanıp
// yanlış hesabın bağlantısı iptal edilebilirdi. Niçin sessiz: takas başarılı
// olduğu için her şey "çalışıyor" görünür.
function fakeIdToken(payload: Record<string, unknown>): string {
  const b64 = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${b64({ alg: "ES256" })}.${b64(payload)}.sig`;
}

Deno.test("id_token.sub oturumdaki Apple kimliğiyle eşleşmezse reddedilir", () => {
  const user = {
    identities: [
      { provider: "google", identity_data: { sub: "g-1" } },
      { provider: "apple", provider_id: "000111.abc", identity_data: { sub: "000111.abc" } },
    ],
  };
  const expected = appleSubjectOf(user);
  assert(expected === "000111.abc", "Apple sub identity_data'dan okunur");
  assert(appleSubjectMatches(fakeIdToken({ sub: "000111.abc" }), expected), "aynı hesap");
  assert(!appleSubjectMatches(fakeIdToken({ sub: "999.zzz" }), expected), "başka hesap");
  assert(!appleSubjectMatches(fakeIdToken({}), expected), "sub yok");
  assert(!appleSubjectMatches("bozuk", expected), "bozuk jeton");
  assert(!appleSubjectMatches(undefined, expected), "jeton yok");
  assert(!appleSubjectMatches(fakeIdToken({ sub: "x" }), null), "kullanıcının Apple sub'ı bilinmiyorsa kapalı başarısız");
});

Deno.test("Apple sub: identity_data yoksa provider_id; Apple kimliği yoksa null", () => {
  assert(appleSubjectOf({ identities: [{ provider: "apple", provider_id: "p1" }] }) === "p1", "provider_id");
  assert(appleSubjectOf({ identities: [{ provider: "google", provider_id: "g" }] }) === null, "google");
  assert(appleSubjectOf({}) === null, "boş");
  assert(decodeJwtPayload("a.b") === null, "bozuk gövde");
});

Deno.test("iptal sonucu: yalnız 200 ve invalid_grant amaca ulaşmıştır (#3)", () => {
  assert(revokeOutcome(200, undefined) === "revoked", "200");
  assert(revokeOutcome(400, "invalid_grant") === "revoked", "zaten geçersiz");
  assert(revokeOutcome(400, "invalid_client") === "failed", "yapılandırma hatası");
  assert(revokeOutcome(500, undefined) === "failed", "5xx");
  assert(revokeOutcome(429, undefined) === "failed", "429");
});

Deno.test("cron sırrı sabit zamanlı karşılaştırılır", () => {
  assert(timingSafeEqual("s", "s") && !timingSafeEqual("s", "t") && !timingSafeEqual("", "s"), "sır");
});

// Copilot RET: takas edilen jeton yazılamayıp Apple iptali de başarısızsa eskiden
// `queued: true` deniyordu, oysa sweep'in göreceği kayıt yoktu.
Deno.test("iptal başarısızlığı: kayıt yoksa queued denmez, revoke_failed_unsaved", () => {
  const saved = revokeFailureBody(true);
  assert(saved.error === "revoke_failed" && saved.queued === true, "saklı jeton kuyrukta");
  const unsaved = revokeFailureBody(false);
  assert(unsaved.error === "revoke_failed_unsaved" && unsaved.queued === false, "saklanamadı");
});
