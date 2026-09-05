-- Salt okunur. 2026-09-02 pentest + XP yazım göçlerinin canlı doğrulaması.
-- Beklenen: anon_profiles_select=false, auth_profiles_select=true,
-- anon_award_xp=false, auth_award_xp=true, provolatile='v',
-- xp_write_present=true, SELECT politikası yalnız authenticated.

select
  has_table_privilege('anon', 'public.profiles', 'select') as anon_profiles_select,
  has_table_privilege('authenticated', 'public.profiles', 'select') as auth_profiles_select,
  has_function_privilege(
    'anon',
    'public.award_xp_delta(integer)',
    'execute'
  ) as anon_award_xp,
  has_function_privilege(
    'authenticated',
    'public.award_xp_delta(integer)',
    'execute'
  ) as auth_award_xp;

select
  p.proname,
  p.provolatile,
  p.prosecdef,
  position(
    'set xp = coalesce(xp, 0) + v_delta'
    in pg_get_functiondef('public.award_xp_delta(integer)'::regprocedure)
  ) > 0 as xp_write_present
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'award_xp_delta';

select policyname, roles, cmd
from pg_policies
where schemaname = 'public'
  and tablename = 'profiles'
order by policyname;
