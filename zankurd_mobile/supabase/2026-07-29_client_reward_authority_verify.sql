-- Salt okunur canlı doğrulama: client reward authority migration.
-- Beklenen: tüm boolean alanlar true, iki sayaç 0; ikinci sorgu false/0/NULL.

with defs as (
  select
    pg_get_functiondef(
      'public.submit_contest_entry(uuid,integer)'::regprocedure
    ) as submit_def,
    pg_get_functiondef(
      'public.claim_contest_reward(uuid)'::regprocedure
    ) as claim_def,
    pg_get_functiondef(
      'public.award_xp_delta(integer)'::regprocedure
    ) as xp_def,
    pg_get_functiondef(
      'public.delete_my_account()'::regprocedure
    ) as delete_def
),
claim_probe as (
  select claimed, rank_reward, badge_awarded
  from public.claim_contest_reward(gen_random_uuid())
)
select jsonb_build_object(
  'submit_guard', submit_def ilike '%contest_verification_required%',
  'submit_no_coin_write', submit_def not ilike '%coin_transactions%',
  'claim_no_coin_write', claim_def not ilike '%coin_transactions%',
  'claim_returns_safe_row', (
    select count(*) = 1
      and coalesce(
        bool_and(
          not claimed
          and rank_reward = 0
          and badge_awarded is null
        ),
        false
      )
    from claim_probe
  ),
  'xp_no_update', xp_def not ilike '%update public.profiles%',
  'delete_releases_created_by',
    delete_def ilike '%update public.questions set created_by = null%',
  'delete_releases_reviewed_by',
    delete_def ilike '%update public.suggested_questions set reviewed_by = null%',
  'authenticated_exec_all',
    has_function_privilege(
      'authenticated',
      'public.submit_contest_entry(uuid,integer)',
      'EXECUTE'
    )
    and has_function_privilege(
      'authenticated',
      'public.claim_contest_reward(uuid)',
      'EXECUTE'
    )
    and has_function_privilege(
      'authenticated',
      'public.award_xp_delta(integer)',
      'EXECUTE'
    )
    and has_function_privilege(
      'authenticated',
      'public.delete_my_account()',
      'EXECUTE'
    ),
  'anon_exec_none',
    not has_function_privilege(
      'anon',
      'public.submit_contest_entry(uuid,integer)',
      'EXECUTE'
    )
    and not has_function_privilege(
      'anon',
      'public.claim_contest_reward(uuid)',
      'EXECUTE'
    )
    and not has_function_privilege(
      'anon',
      'public.award_xp_delta(integer)',
      'EXECUTE'
    )
    and not has_function_privilege(
      'anon',
      'public.delete_my_account()',
      'EXECUTE'
    ),
  'mutation_policies', (
    select count(*)
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename in (
        'contests',
        'contest_entries',
        'contest_badges',
        'user_contest_badges'
      )
      and cmd in ('ALL', 'INSERT', 'UPDATE', 'DELETE')
  ),
  'client_write_grants', (
    select count(*)
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in (
        'contests',
        'contest_entries',
        'contest_badges',
        'user_contest_badges'
      )
      and grantee in ('PUBLIC', 'anon', 'authenticated')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
  ),
  'invalid_player_tags', (
    select count(*)
    from public.profiles
    where player_tag is null
       or player_tag !~ '^[A-Z0-9]{4}$'
  )
) as verification
from defs;

select claimed, rank_reward, badge_awarded
from public.claim_contest_reward(gen_random_uuid());
