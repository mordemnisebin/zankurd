-- Dönemsel liderlik tablosu RPC
-- p_days: 1=günlük, 7=haftalık, 30=aylık, -1=tüm zamanlar
-- Supabase SQL Editor'de çalıştır

create or replace function public.get_leaderboard(
  p_days  integer default -1,
  p_limit integer default 10
) returns table (
  player_id    uuid,
  display_name text,
  total_score  bigint,
  best_streak  bigint,
  rooms_played bigint
) language sql security definer as $$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu') as display_name,
    coalesce(sum(rp.score), 0)         as total_score,
    coalesce(max(rp.streak), 0)        as best_streak,
    count(distinct rp.room_id)         as rooms_played
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    and (
      p_days <= 0
      or r.finished_at >= now() - make_interval(days => p_days)
    )
  group by rp.player_id, p.display_name
  order by total_score desc, best_streak desc, rooms_played desc
  limit p_limit;
$$;

grant execute on function public.get_leaderboard(integer, integer) to anon, authenticated;
