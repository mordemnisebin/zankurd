drop view if exists public.leaderboard_entries;

create view public.leaderboard_entries as
select
  row_number() over (order by coalesce(sum(rp.score), 0) desc, coalesce(max(rp.streak), 0) desc)::integer as rank,
  rp.player_id,
  coalesce(p.display_name, 'Oyuncu') as display_name,
  coalesce(sum(rp.score), 0)::integer as total_score,
  coalesce(max(rp.streak), 0)::integer as best_streak,
  count(distinct rp.room_id)::integer as rooms_played
from public.room_players rp
left join public.profiles p on p.id = rp.player_id
group by rp.player_id, p.display_name
order by total_score desc, best_streak desc, rooms_played desc;

grant select on public.leaderboard_entries to anon, authenticated;
