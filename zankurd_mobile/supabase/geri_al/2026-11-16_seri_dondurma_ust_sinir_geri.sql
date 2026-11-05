-- 2026-11-16_seri_dondurma_ust_sinir.sql geri alma: yalnız yeni işlevi kaldırır;
-- `spend_streak_freeze(text)` ve coin_transactions satırları kalır.
begin;
drop function if exists public.spend_streak_freeze_capped(text);
commit;
