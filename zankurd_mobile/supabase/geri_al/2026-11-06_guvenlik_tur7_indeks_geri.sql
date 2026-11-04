-- 2026-11-06_guvenlik_tur7_indeks_concurrently.sql geri alması (Copilot incelemesi:
-- işlev geri alması indeksleri kaldırmıyordu). begin/commit YOK; CONCURRENTLY
-- transaction içinde çalışmaz. Idempotent.
drop index concurrently if exists public.async_duel_answers_player_answered_idx;
drop index concurrently if exists public.tournament_match_answers_player_answered_idx;
drop index concurrently if exists public.async_duels_open_expiry_idx;
