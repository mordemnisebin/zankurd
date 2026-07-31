# Aşılmış göçler — UYGULAMAYIN

Buradaki dosyalar tarihçe için duruyor. **Canlıda çalıştırılmamalıdırlar.**

## Niçin ayrıldılar

`supabase/` klasörü hem tarihli (`2026-07-22_...sql`) hem tarihsiz
(`submit_answer_function.sql`) dosyalar taşıyor. Tarihli dosyalar rakamla
başladığı için alfabetik sıralamada **başa**, tarihsiz eski dosyalar
**sona** düşüyor.

Yani klasörü sırayla çalıştıran biri — ya da yeni bir kurulum — 2026-07-22
tarihli **sertleştirilmiş** `submit_answer` sürümünün üzerine, tarihsiz
**eski** sürümü yazıyordu. Eski sürüm:

- `set search_path` taşımıyor,
- doğru cevabı `where id = p_question_id` ile doğrudan `questions`'tan
  okuyor,
- sorunun o odaya ait olduğunu ve odanın `status = 'active'` olduğunu
  kontrol etmiyor.

Yani sertleştirme sessizce geri alınabiliyordu (2026-07-31 denetimi).

## Kural

**Uygulama sırası dosya adındaki tarihtir. Tarihsiz dosya uygulanmaz.**

Yeni bir göç her zaman `YYYY-MM-DD_ad.sql` biçiminde adlandırılır ve
ileri yönlüdür (`create or replace`, `if not exists`).

## Buraya taşınanlar

| Dosya | Aşan göç |
|---|---|
| `submit_answer_function.sql` | `2026-07-22_multiplayer_integrity_hardening.sql` |
| `clamp_submit_answer_response_ms.sql` | `2026-07-22_multiplayer_integrity_hardening.sql` |
| `spend_coins.sql` | `2026-07-29_release_readiness_hardening.sql` |
| `quiz_reward_rpc.sql` | `2026-07-29_shop_purchase_integrity_fix.sql` |
| `delete_my_account_rpc.sql` | `2026-07-29_client_reward_authority_fix.sql` |
| `leaderboard_period_rpc.sql` | `2026-07-29_release_readiness_hardening.sql` |
| `daily_spin_rpc.sql` | `2026-07-29_shop_purchase_integrity_fix.sql` + `2026-07-06_spin_wheel_backend.sql` |
| `online_game_sync.sql` | `2026-07-29_shop_purchase_integrity_fix.sql` + `2026-08-01_start_room_game_hardening.sql` |
| `online_multiplayer_ready.sql` | `2026-07-22_multiplayer_integrity_hardening.sql` + `2026-08-01_start_room_game_hardening.sql` |

Son üçü özellikle tehlikeliydi: coin ve ödül fonksiyonları. Sırayla
çalıştırılsalardı 2026-07-29'daki satın alma bütünlüğü ve istemci ödül
yetkisi sertleştirmelerini birlikte geri alıyorlardı.

## Henüz taşınmayanlar — karar gerekiyor

Klasörde hâlâ iki tarihsiz dosya fonksiyon tanımlıyor, ama ikisi de
**çakışmıyor**: tanımladıkları şeyin başka hiçbir sürümü yok, dolayısıyla
alfabetik sıra kimseyi ezmiyor. Bir sakıncaları yok.

- `add_fcm_token.sql` → `set_fcm_token`
- `room_players_rls_fix.sql` → `is_room_participant`

Politika sürtüşmesi olarak iki kayıt duruyor:

- **`public_read_policies.sql`** — `questions` tablosuna anon okuma izni
  veriyor. `2026-07-22_multiplayer_integrity_hardening.sql:3` tam tersini
  yapıyor (`revoke select on public.questions from public, anon,
  authenticated`). İkisi çelişiyor; bu dosya sonradan çalıştırılırsa doğru
  cevap gizlemesi açılır. **Canlıda doğru durum etkin** (2026-08-01
  doğrulaması: `anon_soru_okuyabilir = false`), ama dosya kalırsa bir gün
  yanlış sırayla çalıştırılabilir.
- **`2026-07-13_shop_chat_suggestions.sql:99`** — `room_messages` için
  `USING (true)` okuma politikası kuruyordu.
  `2026-07-31_chat_moderation.sql` bunu oda üyeliği şartına çekti ve
  canlıda doğrulandı. Dosya tarihli olduğu için sıralama sorunu yok, ama
  eski satır hâlâ orada duruyor.

## 2026-08-01'de çözülen düğüm

Dört dosya "tek kaynak oldukları bir şey var" diye bekliyordu. Bekçinin
deseni yalnız `create or replace function` arıyordu ve
`2026-07-29_release_readiness_hardening.sql`in `get_leaderboard`ı
`drop function` + düz `create function` ile yeniden tanımladığını
göremiyordu — imza değiştiği için `or replace` kullanılamıyor.

Desen düzeltilince üçünün zaten tamamen aşılmış olduğu ortaya çıktı.
Geriye iki gerçek benzersizlik kaldı ve ikisi de çözüldü:

* `spin_wheel_history` tablosunu tarihli `2026-07-06_spin_wheel_backend.sql`
  de kuruyor.
* `start_room_game` yalnız iki tarihsiz dosyada vardı ve ikisi TEK bir
  satırda ayrılıyordu: korumalı sürüm `set search_path = public` taşıyor.
  O sürüm `2026-08-01_start_room_game_hardening.sql`e alındı.
