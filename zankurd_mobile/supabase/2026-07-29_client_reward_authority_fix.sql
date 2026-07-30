-- Client reward authority compatibility shutdown (forward-only, idempotent).
--
-- Contest and XP write APIs keep their existing signatures so older clients
-- fail safely while server-verifiable scoring is being designed. These reward
-- compatibility functions do not write score, badge, coin, or XP state.

begin;

create or replace function public.submit_contest_entry(
  p_contest_id uuid,
  p_correct_count integer
)
returns table (
  entry_id uuid,
  score integer,
  rank integer,
  participation_reward integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  raise exception 'contest_verification_required';
end;
$$;

create or replace function public.claim_contest_reward(p_contest_id uuid)
returns table (
  claimed boolean,
  rank_reward integer,
  badge_awarded text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query select false, 0::int, null::text;
end;
$$;

create or replace function public.award_xp_delta(p_delta integer)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_xp integer := 0;
  v_has_xp boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if to_regclass('public.profiles') is null then
    return 0;
  end if;

  select exists (
    select 1
    from pg_catalog.pg_attribute
    where attrelid = to_regclass('public.profiles')
      and attname = 'xp'
      and not attisdropped
  ) into v_has_xp;

  if not v_has_xp then
    return 0;
  end if;

  execute
    'select coalesce(xp, 0)::integer from public.profiles where id = $1'
    into v_xp
    using v_uid;

  return coalesce(v_xp, 0);
end;
$$;

-- Keep account deletion compatible with nullable contributor references that
-- otherwise use NO ACTION and can block deletion of an admin/contributor.
create or replace function public.delete_my_account()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.favorite_questions
  where player_id = v_user_id;

  delete from public.coin_transactions
  where player_id = v_user_id;

  if to_regclass('public.questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.questions')
         and attname = 'created_by'
         and not attisdropped
     ) then
    execute
      'update public.questions set created_by = null where created_by = $1'
      using v_user_id;
  end if;

  if to_regclass('public.suggested_questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.suggested_questions')
         and attname = 'reviewed_by'
         and not attisdropped
     ) then
    execute
      'update public.suggested_questions set reviewed_by = null '
      || 'where reviewed_by = $1'
      using v_user_id;
  end if;

  update public.question_reports
  set reporter_id = null
  where reporter_id = v_user_id;

  delete from public.player_answers
  where player_id = v_user_id;

  delete from public.rooms
  where host_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = v_user_id::text;

  delete from auth.users
  where id = v_user_id;

  return json_build_object('deleted', true);
end;
$$;

-- Contest tables are server-owned. Remove every mutation policy, including
-- policy names introduced outside this repository, and revoke direct writes.
do $$
declare
  v_table text;
  v_policy record;
begin
  foreach v_table in array array[
    'contests',
    'contest_entries',
    'contest_badges',
    'user_contest_badges'
  ]
  loop
    if to_regclass('public.' || quote_ident(v_table)) is null then
      continue;
    end if;

    execute format('alter table public.%I enable row level security', v_table);

    for v_policy in
      select policyname
      from pg_catalog.pg_policies
      where schemaname = 'public'
        and tablename = v_table
        and cmd in ('ALL', 'INSERT', 'UPDATE', 'DELETE')
    loop
      execute format(
        'drop policy if exists %I on public.%I',
        v_policy.policyname,
        v_table
      );
    end loop;

    execute format(
      'revoke insert, update, delete, truncate on table public.%I '
      || 'from public, anon, authenticated',
      v_table
    );
  end loop;
end;
$$;

revoke all on function public.submit_contest_entry(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.submit_contest_entry(uuid, integer)
  to authenticated;

revoke all on function public.claim_contest_reward(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_contest_reward(uuid)
  to authenticated;

revoke all on function public.award_xp_delta(integer)
  from public, anon, authenticated;
grant execute on function public.award_xp_delta(integer)
  to authenticated;

revoke all on function public.delete_my_account()
  from public, anon, authenticated;
grant execute on function public.delete_my_account()
  to authenticated;

commit;
