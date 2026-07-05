-- Avatar + unvan vitrini Supabase migration (2026-07-05)
--
-- Run manually in Supabase SQL Editor after reviewing.
-- This patch supports the app-side avatar editor, leaderboard avatars,
-- matchmaking/player display fallbacks, and Supabase Storage photo upload.
-- It is idempotent: rerunning it should not duplicate columns or policies.

-- 1) Profile cosmetic fields.
alter table public.profiles
  add column if not exists avatar_icon text,
  add column if not exists avatar_color text default '#E94560',
  add column if not exists avatar_url text,
  add column if not exists avatar_frame text,
  add column if not exists showcase_title text;

-- 2) Profile RLS: authenticated users may update their own cosmetic fields.
-- Existing triggers still clamp protected fields such as coins/rating/xp.
drop policy if exists "Users update their own profile"
  on public.profiles;
create policy "Users update their own profile"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- 3) Public avatar photo bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 4) Storage RLS: users may manage only files under their own user-id folder.
drop policy if exists "Avatar photos are publicly readable"
  on storage.objects;
create policy "Avatar photos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "Users upload own avatar photos"
  on storage.objects;
create policy "Users upload own avatar photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users update own avatar photos"
  on storage.objects;
create policy "Users update own avatar photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users delete own avatar photos"
  on storage.objects;
create policy "Users delete own avatar photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5) Leaderboard RPC now returns optional avatar/showcase fields.
-- Older app builds ignore the extra columns; current builds read them null-safely.
drop function if exists public.get_leaderboard(integer, integer);

create function public.get_leaderboard(
  p_days  integer default -1,
  p_limit integer default 10
) returns table (
  player_id      uuid,
  display_name   text,
  total_score    bigint,
  best_streak    bigint,
  rooms_played   bigint,
  avatar_icon    text,
  avatar_color   text,
  avatar_url     text,
  avatar_frame   text,
  showcase_title text
) language sql security definer as $$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu') as display_name,
    coalesce(sum(rp.score), 0)         as total_score,
    coalesce(max(rp.streak), 0)        as best_streak,
    count(distinct rp.room_id)         as rooms_played,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    and (
      p_days <= 0
      or r.finished_at >= now() - make_interval(days => p_days)
    )
  group by
    rp.player_id,
    p.display_name,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  order by total_score desc, best_streak desc, rooms_played desc
  limit p_limit;
$$;

grant execute on function public.get_leaderboard(integer, integer)
  to anon, authenticated;

-- 6) Keep Play-policy account deletion aligned with avatar photos.
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

  delete from public.favorite_questions
  where player_id = v_user_id;

  delete from public.coin_transactions
  where player_id = v_user_id;

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

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
