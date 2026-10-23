-- Sırayla düello: expire_async_duels artık 10 dakikada bir koşar (2026-10-24).
--
-- Niçin: saatlik koşuda (:37) hükmen sonuç ve "4 saat kaldı" hatırlatması 59
-- dakikaya kadar gecikebilirdi. Yeni 24 saatlik pencerede bu, hatırlatmanın
-- ya da kapanışın görünür biçimde geç gelmesi demektir. Fonksiyon her
-- çağrıda yalnız süresi geçmiş / 4 saat içinde dolacak düelloları işler ve
-- hatırlatmayı düello+oyuncu başına bir kez gönderir (`reminder_sent_for`),
-- bu yüzden sık koşması ucuz ve zararsızdır.
--
-- ÖNKOŞUL: 2026-10-24_duello_sirasi.sql önce uygulanmış olmalı (yeni sütunlar
-- ve fonksiyon gövdesi). İdempotent: iş varsa kaldırılıp yeniden kurulur.
-- Uygulama: `supabase db query --linked -f supabase/2026-10-24_duello_sirasi_cron.sql`

begin;

create extension if not exists pg_cron with schema pg_catalog;

select cron.unschedule('expire-async-duels')
where exists (
  select 1 from cron.job where jobname = 'expire-async-duels'
);

select cron.schedule(
  'expire-async-duels',
  '*/10 * * * *',
  $$select public.expire_async_duels()$$
);

commit;
