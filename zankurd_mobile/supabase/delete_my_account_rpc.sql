-- Account deletion RPC for Play policy compliance.
-- Run manually in Supabase SQL Editor after reviewing.
--
-- This function deletes the authenticated user's personal data and then
-- removes the auth user. It does not grant any client-side table writes and
-- does not change coin_transactions RLS policies.

create or replace function public.delete_my_account()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Remove personal activity and user-owned content.
  delete from public.favorite_questions
  where player_id = v_user_id;

  delete from public.coin_transactions
  where player_id = v_user_id;

  -- Release nullable contributor/moderator references before auth deletion.
  -- Guards keep this RPC usable on installations where an optional table or
  -- column has not been deployed yet.
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

  -- Rooms hosted by the deleted user cannot keep a required host_id.
  -- Deleting the room cascades room_questions and room_players for that room.
  delete from public.rooms
  where host_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = v_user_id::text;

  -- Deletes profile through auth.users -> profiles on delete cascade.
  delete from auth.users
  where id = v_user_id;

  return json_build_object('deleted', true);
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
