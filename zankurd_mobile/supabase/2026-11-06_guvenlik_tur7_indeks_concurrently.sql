-- 2026-11-06_guvenlik_tur7.sql ile ilgili indeksler (GPT-6 Pro alan 3, bulgu 13 ve 15).
-- begin/commit YOK: CREATE INDEX CONCURRENTLY transaction içinde çalışmaz; dosya
-- psql/`supabase db query` ile bölünmeden, otomatik transaction olmadan koşulmalıdır.
-- Idempotent; yazmaları BLOKLAMAZ. Göçten önce ya da sonra çalıştırılabilir.
--
-- * profil istatistiği ve haftalık geçmiş RPC'leri (get_my_online_answer_stats/history)
--   async_duel_answers ve tournament_match_answers'ı oyuncu + zaman ile süzer; PK'ler
--   duel_id/match_id ile başlar -> oyuncuya özel sorgu genel geçmişi tarardı.
-- * expire_async_duels kapanış sorgusu (status open/matched, expires_at <= now()).
-- Geri alma: drop index concurrently if exists <ad>;
create index concurrently if not exists async_duel_answers_player_answered_idx
  on public.async_duel_answers (player_id, answered_at) include (choice, is_correct);
create index concurrently if not exists tournament_match_answers_player_answered_idx
  on public.tournament_match_answers (player_id, answered_at) include (choice, is_correct);
create index concurrently if not exists async_duels_open_expiry_idx
  on public.async_duels (expires_at, id) where status in ('open', 'matched');
