// apple-revoke yardımcıları — Deno testi (`deno test supabase/functions/apple-revoke/`).
//
// Kusur (GPT-6 Pro ALAN 4): misafir oturum `register` ile özel anahtarla JWT
// imzalatıp Apple token takasını başlatabiliyor, tekrarlar birleşmiyordu.
// Niçin sessiz: fonksiyon geçerli Supabase kullanıcısı yeterli sayıyordu.
import { hasAppleIdentity, registerRecentlyDone } from "./lib.ts";

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
