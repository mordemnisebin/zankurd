-- TASLAK (G-08, 2026-11-06): canlı şemanın SALT-OKUR parmak izi.
-- Yalnız katalog SELECT'i içerir; yazmaz, yan etkisi yoktur. HENÜZ ÇALIŞTIRILMADI.
-- Kullanım (sahip/ana ajan, izinle): her biri tek satırlık ayrı sorgu olarak
--   supabase db query --linked -f tool/sema_karsilastir_taslak.sql
-- Aynı dosya temiz `supabase db reset` sonrası YEREL veritabanında da koşulur;
-- iki çıktının farkı = göç zincirinin üretemediği şema (docs/GOC_ZINCIRI_PLANI.md).
-- Çıktıyı repo'ya koyma (içinde sahip/ACL ayrıntısı olabilir).

-- 1. Tablolar ve sütunlar (sıralı, deterministik)
select 'sutun' as tur, c.table_name || '.' || c.column_name as ad,
       c.data_type || ':' || c.is_nullable || ':' || coalesce(c.column_default, '') as ayrinti
from information_schema.columns c
where c.table_schema = 'public'
order by 2;

-- 2. İndeksler
select 'indeks' as tur, i.tablename || '.' || i.indexname as ad, md5(i.indexdef) as ayrinti
from pg_indexes i
where i.schemaname = 'public'
order by 2;

-- 3. İşlevler: imza + gövde md5 + SECURITY DEFINER + search_path
select 'islev' as tur, p.oid::regprocedure::text as ad,
       md5(pg_get_functiondef(p.oid)) || ':' || p.prosecdef::text || ':' ||
       coalesce(array_to_string(p.proconfig, ','), '') as ayrinti
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by 2;

-- 4. Tetikleyiciler
select 'tetikleyici' as tur, c.relname || '.' || t.tgname as ad,
       md5(pg_get_triggerdef(t.oid)) as ayrinti
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and not t.tgisinternal
order by 2;

-- 5. RLS politikaları
select 'politika' as tur, p.tablename || '.' || p.policyname as ad,
       md5(coalesce(p.qual, '') || '|' || coalesce(p.with_check, '') || '|' || p.cmd || '|' || array_to_string(p.roles, ',')) as ayrinti
from pg_policies p
where p.schemaname = 'public'
order by 2;

-- 6. pg_cron işleri (yalnız ad + zamanlama; komut md5)
select 'cron' as tur, j.jobname as ad, j.schedule || ':' || md5(j.command) as ayrinti
from cron.job j
order by 2;
