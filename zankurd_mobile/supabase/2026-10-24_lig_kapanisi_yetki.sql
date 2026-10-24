-- Haftalık lig kapanışı yalnız zamanlayıcıdan çalışır (2026-10-24).
--
-- Niçin: `finalize_weekly_league(date)` SECURITY DEFINER ve `authenticated`
-- rolüne açıktı; gövdesinde çağıran denetimi yok. Giriş yapmış herhangi bir
-- oyuncu `rpc('finalize_weekly_league', {p_week: ...})` ile süren haftanın
-- lig üyeliklerini silip yarım skorlarla yeniden yazabiliyor ve haftayı
-- `closed` yapabiliyordu. İstemci bu fonksiyonu hiç çağırmıyor; yalnız
-- pg_cron (postgres rolü) çağırır, o da bu geri almadan etkilenmez.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-24_lig_kapanisi_yetki.sql

begin;

revoke execute on function public.finalize_weekly_league(date) from public, anon, authenticated;

commit;
