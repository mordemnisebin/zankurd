-- 2026-11-18_w9_olcek.sql ile ilgili indeksler (ChatGPT Pro alan 9 #11, #15).
-- begin/commit YOK: CREATE INDEX CONCURRENTLY transaction içinde çalışmaz; dosya
-- psql/`supabase db query` ile bölünmeden koşulmalıdır. Idempotent; yazmaları
-- BLOKLAMAZ. Göçten önce ya da sonra çalıştırılabilir.
--
-- * #11 jeton bakiyesi: `select sum(amount) from coin_transactions where
--   player_id = ...` oda kurma/ödül yollarında çalışır. Kod deposunda
--   (player_id) için DÜZ indeks yok (yalnız kısmi benzersiz indeksler); canlıda
--   varsa bu komut no-op'a yakındır. (player_id) INCLUDE (amount) bakiyeyi
--   yığına gitmeden indeksten (index-only scan) toplar. Oyuncu başına özet
--   tablo BİLEREK eklenmedi: yazma yolundaki tutarlılık/göç riski; yük
--   ölçümü (EXPLAIN ANALYZE, 10.000 oyuncu) sonrası karar verilmeli.
-- * #15 verified_solo_selections süpürmesi created_at ile süzer; mevcut indeks
--   (user_id, created_at desc) bu sorguyu desteklemez.
-- Geri alma: geri_al/2026-11-18_w9_olcek_geri.sql (indeksleri de kaldırır)
create index concurrently if not exists coin_transactions_player_amount_idx
  on public.coin_transactions (player_id) include (amount);
create index concurrently if not exists verified_solo_selections_created_idx
  on public.verified_solo_selections (created_at);
