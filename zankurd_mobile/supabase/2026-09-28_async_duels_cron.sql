-- Sırayla düello: süresi dolan açık/eşleşmiş düelloları saatlik kapatır.
-- Ön koşul: pg_cron (cleanup-stale-rooms zaten çalışıyorsa yüklü).
-- expire_async_duels yalnız service_role çalıştırabilir; pg_cron işi
-- `postgres` rolüyle çalışır (finalize-weekly-league ve cleanup-stale-rooms
-- ile aynı desen — bkz. 2026-08-26_weekly_league_cron.sql).
--
-- Bu dosya da 2026-09-28_async_duels.sql ile birlikte UYGULANMAMIŞTIR.

begin;

create extension if not exists pg_cron with schema pg_catalog;

select cron.unschedule('expire-async-duels')
where exists (
  select 1 from cron.job where jobname = 'expire-async-duels'
);

select cron.schedule(
  'expire-async-duels',
  '37 * * * *',
  $$select public.expire_async_duels()$$
);

commit;
