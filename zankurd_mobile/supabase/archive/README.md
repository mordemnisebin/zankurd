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

Son üçü özellikle tehlikeliydi: coin ve ödül fonksiyonları. Sırayla
çalıştırılsalardı 2026-07-29'daki satın alma bütünlüğü ve istemci ödül
yetkisi sertleştirmelerini birlikte geri alıyorlardı.

## Henüz taşınmayanlar — karar gerekiyor

Aşağıdaki tarihsiz dosyalar **hâlâ tek kaynak** oldukları bir şey
tanımlıyor, o yüzden taşınmadılar. Ama aynı zamanda aşılmış tanımlar da
içeriyorlar; sırayla çalıştırılırlarsa aynı tehlikeyi taşırlar. Her biri
tarihli bir göçe bölünmeli.

- **`online_multiplayer_ready.sql`** — `start_room_game` için tek kaynak,
  ama `submit_answer`ın eski sürümünü de tanımlıyor.
- **`online_game_sync.sql`** — `start_room_game` için tek kaynak, ama
  `finish_room_game`in eski sürümünü de tanımlıyor.
- **`leaderboard_period_rpc.sql`** — `get_leaderboard` için tek kaynak.
  Eski sürümünde `limit p_limit` sınırsız.
- **`daily_spin_rpc.sql`** — `spin_wheel_history` tablosunu kurar, ama
  `claim_daily_spin`in eski sürümünü de tanımlıyor.
- **`public_read_policies.sql`** — `questions` tablosuna anon okuma izni
  veriyor. `2026-07-22_multiplayer_integrity_hardening.sql:3` tam tersini
  yapıyor (`revoke select on public.questions from public, anon,
  authenticated`). İkisi çelişiyor; bu dosya sonradan çalıştırılırsa
  doğru cevap gizlemesi açılır.
- **`2026-07-13_shop_chat_suggestions.sql:99`** — `room_messages` için
  `USING (true)` okuma politikası kuruyor, yani odaya ait olmayan da
  mesajları okuyabilir.

Bunların hiçbiri canlı veritabanına bakmadan güvenle çözülemez; bu yüzden
kod tarafında değil, burada karar bekliyorlar.

Bunlar canlı veritabanının şu anki durumuna bakmadan güvenle
düzeltilemez; `applied.md` ile karşılaştırılıp tarihli göçlere bölünmeleri
gerekiyor.
