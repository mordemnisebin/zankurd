-- 2026-11-18_w9_olcek.sql geri alma: zamanlamaları eski değerlerine döndürür,
-- yeni süpürme işini ve işlevini kaldırır. Gövdelere ve cron komutlarına dokunulmadı,
-- dolayısıyla geri alınacak gövde yok. İndeksler transaction dışında kaldırılır
-- (aşağıdaki iki satırı ayrı koşun; istenmezse bırakılabilir, zararsızdır).
begin;

do $geri$
declare
  r record;
begin
  for r in select * from (values
    ('push-outbox-retention',   '20 0 * * *'),
    ('rate-limit-events-sweep', '25 0 * * *'),
    ('idempotent-ops-temizlik', '47 3 * * *')) t(ad, eski)
  loop
    perform cron.alter_job(j.jobid, schedule := r.eski)
    from cron.job j where j.jobname = r.ad;
    delete from public.olcek_tur3_yedek where ad = 'w9:cron:' || r.ad;
  end loop;
end
$geri$;

select cron.unschedule('verified-solo-selections-sweep')
where exists (select 1 from cron.job where jobname = 'verified-solo-selections-sweep');

drop function if exists public.verified_solo_selections_sweep(integer);

commit;

-- Transaction DIŞI (ayrı koşun):
-- drop index concurrently if exists public.coin_transactions_player_amount_idx;
-- drop index concurrently if exists public.verified_solo_selections_created_idx;
