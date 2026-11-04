-- 2026-11-07_idempotency_temizlik.sql geri alma: işi kaldırır, indeksi siler.
-- Silinmiş eski kayıtlar geri gelmez (zaten 14 günü aşmışlardı).
begin;

select cron.unschedule('idempotent-ops-temizlik')
where exists (select 1 from cron.job where jobname = 'idempotent-ops-temizlik');

drop index if exists public.idempotent_ops_created_at_idx;

commit;
