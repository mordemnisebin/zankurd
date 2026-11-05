-- ZanKurd 2.2 — Yönetim: dönem sonu otomatik ödül işi (CANLIDA: 2026-11-05 uygulandı, bkz. applied.md).
--
-- Niçin: panelde "otomatik ödül" anahtarı vardı ama onu okuyan hiçbir şey yoktu
-- (11-12 taslağında "cron yok" yazılıydı). Bu iş her gece 00:10'da (İstanbul =
-- 21:10 UTC; pg_cron UTC çalışır, İstanbul yaz saati kullanmaz) `admin_run_auto_rewards()`
-- çağırır. İşlev anahtar KAPALIYSA hiçbir şey yapmaz (varsayılan kapalı), açıksa
-- biten günün yarışması ve haftalık sıralama ilk 3'üne jetonu verir; aynı
-- dönem/kişi ikinci kez verilmez (`admin_reward_grants` tekilliği), elle verilmişse
-- atlanır. Cron'un kendisi para hareketi yapmaz; kararı anahtar verir.
--
-- Önkoşul: 2026-11-12_yonetim_paneli.sql (işlev) uygulanmış olmalı.
-- İdempotent: iş varsa kaldırılıp yeniden kurulur (aynı ad tek kopya).
-- Uygulama: supabase db query --linked -f supabase/2026-11-13_yonetim_otomatik_odul_cron.sql
-- Geri alma: supabase/geri_al/2026-11-13_yonetim_otomatik_odul_cron_geri.sql
begin;

do $onkosul$
begin
  if to_regprocedure('public.admin_run_auto_rewards()') is null then
    raise exception 'yonetim cron: admin_run_auto_rewards() yok; önce 2026-11-12_yonetim_paneli.sql';
  end if;
end;
$onkosul$;

create extension if not exists pg_cron with schema pg_catalog;

select cron.unschedule('yonetim-otomatik-odul')
where exists (select 1 from cron.job where jobname = 'yonetim-otomatik-odul');

select cron.schedule(
  'yonetim-otomatik-odul',
  '10 21 * * *',
  $$select public.admin_run_auto_rewards()$$
);

do $son$
begin
  if (select count(*) from cron.job where jobname = 'yonetim-otomatik-odul'
        and schedule = '10 21 * * *'
        and command like '%admin_run_auto_rewards%') <> 1 then
    raise exception 'yonetim cron: iş kurulamadı ya da tek kopya değil';
  end if;
end;
$son$;

commit;
