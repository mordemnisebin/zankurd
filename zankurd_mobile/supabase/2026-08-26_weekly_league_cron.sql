-- Haftalık lig kapanışı. Tablolar ve `finalize_weekly_league` canlıda;
-- 2026-08-26 katalogda `cron.job` kaydı yoktu.
-- Ön koşul: pg_cron (cleanup-stale-rooms zaten çalışıyorsa yüklü).
-- finalize_weekly_league yalnız service_role / süper kullanıcı;
-- pg_cron postgres rolüyle çalışır.

create extension if not exists pg_cron with schema pg_catalog;

select cron.unschedule('finalize-weekly-league')
where exists (
  select 1 from cron.job where jobname = 'finalize-weekly-league'
);

select cron.schedule(
  'finalize-weekly-league',
  '5 0 * * 1',
  $$select public.finalize_weekly_league()$$
);
