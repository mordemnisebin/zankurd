-- 2026-07-21 denetimi (devam): cleanup_stale_rooms() için pg_cron zamanlaması.
-- Ön koşul: cleanup_stale_rooms() fonksiyonu zaten canlıda (2026-07-21_room_cleanup.sql
-- uygulandı, bkz. supabase/applied.md).
--
-- Bu dosyayı SQL Editor'de ÇALIŞTIR. `create extension` süper kullanıcı
-- yetkisi gerektirir; Supabase projelerinde SQL Editor bunu genelde sorunsuz
-- çalıştırır (Dashboard > Database > Extensions'ta "pg_cron" da elle
-- açılabilir, ikisi de aynı sonucu verir).

create extension if not exists pg_cron with schema pg_catalog;

-- Aynı isimli iş zaten varsa önce kaldır (idempotent yeniden çalıştırma için).
select cron.unschedule('cleanup-stale-rooms')
where exists (
  select 1 from cron.job where jobname = 'cleanup-stale-rooms'
);

select cron.schedule(
  'cleanup-stale-rooms',
  '17 * * * *',  -- her saat :17'de (yoğun dakikalardan kaçınmak için ötelendi)
  $$select public.cleanup_stale_rooms()$$
);

-- Doğrulama:
-- select jobname, schedule, active from cron.job where jobname = 'cleanup-stale-rooms';
-- (bir sonraki çalışmadan sonra) select * from cron.job_run_details
--   where jobid = (select jobid from cron.job where jobname = 'cleanup-stale-rooms')
--   order by start_time desc limit 5;
