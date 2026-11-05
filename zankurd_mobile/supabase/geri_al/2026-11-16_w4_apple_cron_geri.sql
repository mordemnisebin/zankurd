-- 2026-11-16_w4_apple_cron.sql geri alma: yetim Apple jetonu yeniden deneme işini kaldırır.
-- Bekleyen yetim jetonlar tabloda kalır (iptal edilmemiş bağlantılar için elle incele).
begin;

select cron.unschedule('apple-iptal-yeniden')
where exists (select 1 from cron.job where jobname = 'apple-iptal-yeniden');

commit;
