# correct_option istemciye açık — tarihî risk kaydı (2026-07-21)

> **TARİHÎ — kaynak değil.** Canlı durum `applied.md` ve 2026-07-22 /
> 2026-09-06 göçleridir.

## 2026-07-22 sonrası durum

`questions` tablosunda doğrudan SELECT 2026-07-22
(`2026-07-22_multiplayer_integrity_hardening.sql`, `REVOKE SELECT`) ile
kapatıldı. Solo quiz offline bankadan beslenir. Online odalar
`get_room_questions` RPC'si üzerinden gelir.

## Kalan risk

Reveal RPC `correct_option`'ı yalnız mevcut indeksten önceki sorularda
veya oda `finished` iken döndürmelidir
(`2026-09-06_get_room_questions_revealed.sql`). Canlıya basılmadan önce
eski gövde mevcut sorunun harfini de verebilir.

## 2026-07-21 notu (o günkü durum)

`public_read_policies.sql` ile `questions` tablosu (onaylılar) `anon` dahil
tüm istemcilere **`correct_option` kolonu dahil** okunabiliyordu. Online 1v1 /
odalarda `submit_answer` doğruluğu sunucuda hesaplasa da, hileci bir istemci
REST API'den sorunun doğru cevabını maçtan önce okuyabilirdi.

O gün kapatılmama gerekçesi: istemci solo quiz akışında doğru cevabı yerelde
göstermek için `correct_option`'ı bizzat SELECT ediyordu. Kolonu RLS/view ile
gizlemek o zamanki solo yolu kırardı. Doğru çözüm iki adımdı ve sonradan
yapıldı: solo offline banka; online `correct_option`'sız veya reveal-gated RPC.
