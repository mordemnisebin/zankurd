-- idempotent_ops için genel temizlik işi (GPT-6 Pro ALAN 10, 2026-11-04).
--
-- Niçin: tur9'daki çark/düello işlevleri 14 günden eski kayıtları yalnız ÇAĞIRAN
-- kullanıcı için, o kullanıcı yeni bir işlem anahtarı işlerken siliyordu.
-- Uygulamayı bırakan ama hesabını silmeyen kullanıcının kayıtları (düello
-- `result` jsonb'si dahil) süresiz birikirdi. Bu göç günlük bir pg_cron işiyle
-- 14 günlük tekrar-deneme penceresini KORUYARAK eski kayıtları siler. tur9
-- işlevlerine dokunmaz (onların kullanıcı başına temizliği zararsız kalır).
--
-- Tasarım: tek çalıştırmada en çok 20000 satır (`for update skip locked`; sıcak
-- işlemle çakışmaz, kuyruk bir sonraki gün sürer). `created_at` indeksi
-- sınırlı taramayı ucuz tutar.
--
-- Ön koşul: 2026-11-07_idempotency_tur9.sql uygulanmış (tablo var) ve
-- 'idempotent-ops-temizlik' adlı iş HENÜZ yok (yeniden uygulamayı reddeder).
-- Geri alma: geri_al/2026-11-07_idempotency_temizlik_geri.sql
-- Uygulama: `supabase db query --linked -f supabase/2026-11-07_idempotency_temizlik.sql`

begin;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if to_regclass('public.idempotent_ops') is null then
    raise exception 'ön koşul: public.idempotent_ops yok (tur9 uygulanmamış)';
  end if;
  if exists (select 1 from cron.job where jobname = 'idempotent-ops-temizlik') then
    raise exception 'göç zaten uygulanmış: idempotent-ops-temizlik işi var';
  end if;
end
$$;

create index if not exists idempotent_ops_created_at_idx
  on public.idempotent_ops (created_at);

select cron.schedule(
  'idempotent-ops-temizlik',
  '47 3 * * *',
  $job$
  delete from public.idempotent_ops o
  where (o.user_id, o.op_key) in (
    select user_id, op_key
    from public.idempotent_ops
    where created_at < now() - interval '14 days'
    order by created_at
    limit 20000
    for update skip locked
  )
  $job$
);

commit;
