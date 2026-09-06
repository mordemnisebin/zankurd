-- 2026-09-06: turnuva ve yarışma tablolarında anon GRANT kapatılır.
--
-- Baseline `GRANT ALL ... TO anon` bırakmıştı. İstemci bu tablolara
-- doğrudan yazmaz; okuma RPC üzerindendir. authenticated SELECT durur.
-- Idempotent.

revoke all on table public.tournaments from anon;
revoke all on table public.tournament_entries from anon;
revoke all on table public.tournament_matches from anon;
revoke all on table public.tournament_progress from anon;

revoke all on table public.contests from anon;
revoke all on table public.contest_entries from anon;
revoke all on table public.contest_badges from anon;
revoke all on table public.user_contest_badges from anon;
