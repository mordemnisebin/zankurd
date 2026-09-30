-- 2026-09-30: Sırayla düello göçlerinin SALT OKUNUR doğrulaması.
-- Şema ya da veri değiştirmez; yalnız SELECT. Dört göç uygulandıktan sonra:
--   2026-09-22_xp_and_coin_idempotency.sql
--   2026-09-28_async_duels.sql
--   2026-09-28_async_duels_cron.sql
--   2026-09-28_hidden_categories_inactive.sql
-- Çalıştırma:
--   supabase db query --linked -f supabase/2026-09-30_async_duels_verify.sql
-- Her sorgunun başlığında BEKLENEN sonuç yazılıdır. `ok` sütunu olan
-- sorgularda hiçbir satır `false` olmamalıdır. Son sorgu (0) tek satırlık
-- özettir: `hepsi_tamam` true olmalı.

-- 1) Tablolar var mı, RLS açık mı? (beklenen: 5 satır, hepsi ok true.
--    async_* tablolarında RLS ayrıca ZORLANMIŞ olmalı (rls_force true);
--    xp_award_keys/idempotent_spends'te force gerekmez.)
select c.relname as tablo,
       c.relrowsecurity as rls,
       c.relforcerowsecurity as rls_force,
       (c.relrowsecurity
        and (c.relforcerowsecurity
             or c.relname in ('xp_award_keys', 'idempotent_spends'))
       ) as ok
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('async_duels', 'async_duel_answers', 'async_duel_results',
                    'xp_award_keys', 'idempotent_spends')
order by 1;

-- 2) Tablolarda istemci politikası OLMAMALI (beklenen: 0 satır).
select schemaname, tablename, policyname
from pg_policies
where schemaname = 'public'
  and tablename in ('async_duels', 'async_duel_answers', 'async_duel_results',
                    'xp_award_keys', 'idempotent_spends');

-- 3) anon/authenticated bu tablolara doğrudan dokunamamalı
--    (beklenen: 5 satır, hepsi ok true).
select t as tablo,
       has_table_privilege('anon', 'public.' || t, 'select') as anon_select,
       has_table_privilege('authenticated', 'public.' || t, 'select') as auth_select,
       has_table_privilege('authenticated', 'public.' || t, 'insert') as auth_insert,
       has_table_privilege('authenticated', 'public.' || t, 'update') as auth_update,
       has_table_privilege('authenticated', 'public.' || t, 'delete') as auth_delete,
       not (
         has_table_privilege('anon', 'public.' || t, 'select')
         or has_table_privilege('authenticated', 'public.' || t, 'select')
         or has_table_privilege('authenticated', 'public.' || t, 'insert')
         or has_table_privilege('authenticated', 'public.' || t, 'update')
         or has_table_privilege('authenticated', 'public.' || t, 'delete')
       ) as ok
from unnest(array['async_duels', 'async_duel_answers', 'async_duel_results',
                  'xp_award_keys', 'idempotent_spends']) as t
order by 1;

-- 4) Fonksiyonlar: var, SECURITY DEFINER, search_path=public ve yetkiler.
--    Beklenen: 9 satır, hepsi ok true.
--    * İstemciye açık (authenticated true, anon false): start_async_duel,
--      answer_async_duel, list_my_async_duels, mark_async_duel_seen,
--      claim_async_duel_xp, spend_coins_once.
--    * Yalnız service_role (authenticated false, anon false): expire_async_duels,
--      award_xp_delta_once. award_xp_delta da authenticated'a KAPANMIŞ olmalı.
with expected(fn, want_authenticated) as (
  values
    ('public.start_async_duel(text)', true),
    ('public.answer_async_duel(uuid, integer, text, integer)', true),
    ('public.list_my_async_duels()', true),
    ('public.mark_async_duel_seen(uuid)', true),
    ('public.claim_async_duel_xp(uuid)', true),
    ('public.spend_coins_once(integer, text, text)', true),
    ('public.expire_async_duels()', false),
    ('public.award_xp_delta_once(integer, text)', false),
    ('public.award_xp_delta(integer)', false)
)
select e.fn,
       p.prosecdef as security_definer,
       p.proconfig as ayar,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
       has_function_privilege('service_role', p.oid, 'execute') as service_exec,
       (p.prosecdef
        and p.proconfig @> array['search_path=public']
        and not has_function_privilege('anon', p.oid, 'execute')
        and has_function_privilege('authenticated', p.oid, 'execute') = e.want_authenticated
        and has_function_privilege('service_role', p.oid, 'execute')
       ) as ok
from expected e
join pg_proc p on p.oid = to_regprocedure(e.fn)
order by e.fn;

-- 5) Beklenen 9 fonksiyonun hepsi katalogda mı? (beklenen: 9)
select count(*) as bulunan_fonksiyon
from unnest(array[
  'public.start_async_duel(text)',
  'public.answer_async_duel(uuid, integer, text, integer)',
  'public.list_my_async_duels()',
  'public.mark_async_duel_seen(uuid)',
  'public.claim_async_duel_xp(uuid)',
  'public.spend_coins_once(integer, text, text)',
  'public.expire_async_duels()',
  'public.award_xp_delta_once(integer, text)',
  'public.award_xp_delta(integer)'
]) as fn
where to_regprocedure(fn) is not null;

-- 6) Cron işi: tam bir tane, aktif, saatlik, doğru komut
--    (beklenen: 1 satır, ok true). Eski işler (cleanup-stale-rooms,
--    finalize-weekly-league) yerinde kalmalı: aşağıdaki 6b.
select jobid, jobname, schedule, command, active, username,
       (schedule = '37 * * * *'
        and command = 'select public.expire_async_duels()'
        and active
       ) as ok
from cron.job
where jobname = 'expire-async-duels';

-- 6b) Diğer cron işleri dokunulmamış olmalı (beklenen: 3 satır toplam
--     iş: cleanup-stale-rooms, finalize-weekly-league, expire-async-duels).
select jobname, schedule, active from cron.job order by jobname;

-- 7) Kategori aktiflikleri (beklenen: Paradigma, Siyaset, Teknolojî
--    is_active false; Çand, Cografya, Dîrok, Edebiyat, Muzîk, Sînema, Ziman
--    true). Sînema'nın 103 onaylı sorusu hâlâ orada olmalı.
select c.name, c.is_active,
       (select count(*) from questions q
         where q.category_id = c.id and q.is_approved) as onayli_soru,
       (c.is_active = (c.name not in ('Paradigma', 'Siyaset', 'Teknolojî'))) as ok
from categories c
order by c.name;

-- 8) Düello havuzu: gizli olmayan her aktif kategoride >= 7 oynanabilir
--    soru olmalı (start_async_duel 7 seçer; altındaysa 'No questions').
--    Beklenen: her satır ok true. Süzgeç start_async_duel ile birebir.
select c.name, count(*) as oynanabilir,
       (count(*) >= 7) as ok
from questions q
join categories c on c.id = q.category_id
where q.is_approved = true
  and c.is_active = true
  and c.name not in ('Paradigma', 'Siyaset', 'Teknolojî')
  and btrim(coalesce(q.prompt, '')) <> ''
  and btrim(coalesce(q.option_a, '')) not in ('', '-')
  and btrim(coalesce(q.option_b, '')) not in ('', '-')
  and (
    (coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
     and btrim(coalesce(q.option_c, '')) not in ('', '-')
     and btrim(coalesce(q.option_d, '')) not in ('', '-')
     and q.correct_option in ('A', 'B', 'C', 'D'))
    or (q.question_type = 'true_false'
        and btrim(coalesce(q.option_c, '')) in ('', '-')
        and btrim(coalesce(q.option_d, '')) in ('', '-')
        and q.correct_option in ('A', 'B'))
  )
group by c.name
order by c.name;

-- 9) Devam eden odalar gizlenen kategorilere bağlı kalmamış olmalı
--    (bilgi amaçlı; beklenen: 0 satır — lobby/active/reveal durumunda
--    gizli kategorili oda yok). Bitmiş odalar önemsizdir.
select r.status, c.name, count(*) as oda
from rooms r
join categories c on c.id = r.category_id
where c.name in ('Paradigma', 'Siyaset', 'Teknolojî')
  and r.status in ('lobby', 'active', 'reveal')
group by r.status, c.name;

-- 0) ÖZET: hepsi_tamam true olmalı. (Tablolar, fonksiyonlar, cron, kategoriler.)
select (
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('async_duels', 'async_duel_answers', 'async_duel_results',
                        'xp_award_keys', 'idempotent_spends')
      and c.relrowsecurity) = 5
  and (select count(*) from unnest(array[
        'public.start_async_duel(text)',
        'public.answer_async_duel(uuid, integer, text, integer)',
        'public.list_my_async_duels()',
        'public.mark_async_duel_seen(uuid)',
        'public.claim_async_duel_xp(uuid)',
        'public.spend_coins_once(integer, text, text)',
        'public.expire_async_duels()',
        'public.award_xp_delta_once(integer, text)',
        'public.award_xp_delta(integer)']) as fn
       where to_regprocedure(fn) is not null) = 9
  and (select count(*) from cron.job
        where jobname = 'expire-async-duels' and active
          and schedule = '37 * * * *') = 1
  and not has_function_privilege('authenticated', 'public.expire_async_duels()', 'execute')
  and not has_function_privilege('authenticated', 'public.award_xp_delta(integer)', 'execute')
  and has_function_privilege('authenticated', 'public.start_async_duel(text)', 'execute')
  and (select count(*) from categories
        where name in ('Paradigma', 'Siyaset', 'Teknolojî') and is_active) = 0
  and (select count(*) from categories
        where name not in ('Paradigma', 'Siyaset', 'Teknolojî') and not is_active) = 0
) as hepsi_tamam;
