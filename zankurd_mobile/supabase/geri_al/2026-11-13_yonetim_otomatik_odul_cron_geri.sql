-- 2026-11-13_yonetim_otomatik_odul_cron.sql geri alma: gece işini kaldırır.
-- Verilmiş ödüller geri alınmaz; `admin_run_auto_rewards()` işlevi kalır (ama
-- çağıran kalmaz). Anahtarı (admin_set_auto_reward) kapatmak aynı işi görür.
begin;

select cron.unschedule('yonetim-otomatik-odul')
where exists (select 1 from cron.job where jobname = 'yonetim-otomatik-odul');

commit;
