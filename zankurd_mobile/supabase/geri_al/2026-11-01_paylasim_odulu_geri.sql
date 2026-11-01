-- Geri alma: 2026-11-01_paylasim_odulu.sql
-- İşlev kaldırılır; istemci yokluğunda (42883/PGRST202) ödül vermez.
-- `share_reward_claims` ve verilmiş jetonlar (coin_transactions) KORUNUR.
begin;

drop function if exists public.claim_share_reward();

commit;
