-- 2026-11-08_avatar_supurme.sql geri alma: saatlik süpürme işini kaldırır.
-- Daha önce silinen dosyalar geri gelmez (zaten sahipsizdi).
begin;

select cron.unschedule('avatar-supurme')
where exists (select 1 from cron.job where jobname = 'avatar-supurme');

commit;
