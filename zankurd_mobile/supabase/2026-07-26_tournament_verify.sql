-- Turnuva kurulumunu doğrulama — Supabase SQL editöründe çalıştır.
-- Hiçbir şeyi değiştirmez; yalnız okur ve bir "sağlık raporu" basar.

-- 1) Nesneler yerinde mi?
select 'tablo: ' || table_name as kontrol, 'var' as durum
  from information_schema.tables
 where table_schema = 'public'
   and table_name in ('tournaments', 'tournament_entries',
                      'tournament_matches')
union all
select 'fonksiyon: ' || routine_name, 'var'
  from information_schema.routines
 where routine_schema = 'public'
   and routine_name in ('join_tournament', 'submit_tournament_match',
                        'get_tournament_bracket', 'start_tournament',
                        'advance_tournament', 'start_due_tournaments',
                        'resolve_expired_tournament_matches')
order by 1;
-- Beklenen: 3 tablo + 7 fonksiyon = 10 satır.

-- 2) Yazma yolu gerçekten kapalı mı?
--    Tablolarda RLS açık olmalı ve YALNIZ select politikası bulunmalı.
--    Buradan insert/update çıkarsa skor istemciden yazılabiliyor demektir.
select c.relname as tablo,
       c.relrowsecurity as rls_acik,
       coalesce(string_agg(p.polcmd::text, ','), 'politika yok') as komutlar
  from pg_class c
  left join pg_policy p on p.polrelid = c.oid
 where c.relname in ('tournaments', 'tournament_entries',
                     'tournament_matches')
 group by c.relname, c.relrowsecurity
 order by 1;
-- Beklenen: rls_acik = true, komutlar = 'r' (yalnız select).

-- 3) Şu anki durum.
select t.id,
       t.status,
       t.size,
       t.min_size,
       t.opened_at,
       t.opened_at + make_interval(hours => t.fill_hours) as baslama_siniri,
       (select count(*) from public.tournament_entries e
         where e.tournament_id = t.id) as katilimci,
       (select count(*) from public.tournament_matches m
         where m.tournament_id = t.id) as mac
  from public.tournaments t
 order by t.opened_at desc
 limit 5;
