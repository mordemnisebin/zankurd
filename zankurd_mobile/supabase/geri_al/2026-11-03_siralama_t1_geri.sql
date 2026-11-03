-- Geri alma: 2026-11-03_siralama_t1.sql
-- Arkadaş RPC'si kaldırılır, 2026-10-16 canlı tanımlarındaki günlük 5000
-- puan tavanı iki genel sıralama fonksiyonuna geri getirilir.
begin;

drop function if exists public.get_friends_leaderboard(integer);

create or replace function public.get_leaderboard(p_days integer default -1, p_limit integer default 10)
returns table(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      least(coalesce(sum(rp.score), 0), 5000)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  )
  select
    pd.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(pd.day_score), 0)::bigint,
    coalesce(max(pd.day_streak), 0)::bigint,
    coalesce(sum(pd.day_rooms), 0)::bigint,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from per_day pd
  left join public.profiles p on p.id = pd.player_id
  group by
    pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(pd.day_score), 0) > 0
  order by coalesce(sum(pd.day_score), 0) desc,
    coalesce(max(pd.day_streak), 0) desc,
    coalesce(sum(pd.day_rooms), 0) desc,
    pd.player_id asc
  limit least(greatest(p_limit, 1), 100);
$function$;

create or replace function public.get_my_leaderboard_rank(p_days integer default -1)
returns table(rank bigint, player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      least(coalesce(sum(rp.score), 0), 5000)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0
        or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  ),
  board as (
    select
      pd.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(pd.day_score), 0)::bigint as total_score,
      coalesce(max(pd.day_streak), 0)::bigint as best_streak,
      coalesce(sum(pd.day_rooms), 0)::bigint as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from per_day pd
    left join public.profiles p on p.id = pd.player_id
    group by
      pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(pd.day_score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc,
          b.player_id asc
      ) as row_no
    from board b
  )
  select
    o.row_no as rank,
    o.player_id,
    o.display_name,
    o.total_score,
    o.best_streak,
    o.rooms_played,
    o.avatar_icon,
    o.avatar_color,
    o.avatar_url,
    o.avatar_frame,
    o.showcase_title
  from ordered o
  where o.player_id = auth.uid()
  limit 1;
$function$;

commit;
