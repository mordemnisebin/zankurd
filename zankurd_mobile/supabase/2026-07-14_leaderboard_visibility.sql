-- Oda oyuncularini profil kaydi olmasa bile leaderboard'a dahil eder.

drop view if exists public.leaderboard_entries;

create view public.leaderboard_entries as
with leaderboard_players as (
  select id as player_id from public.profiles
  union
  select distinct player_id from public.room_players
)
select
  row_number() over (order by coalesce(p.xp, 0) desc, lp.player_id)::integer as rank,
  lp.player_id,
  coalesce(p.display_name, 'Oyuncu') as display_name,
  coalesce(p.xp, 0)::integer as total_score,
  0::integer as best_streak,
  0::integer as rooms_played,
  p.avatar_icon,
  p.avatar_color,
  p.avatar_url,
  p.avatar_frame,
  p.showcase_title
from leaderboard_players lp
left join public.profiles p on p.id = lp.player_id;

grant select on public.leaderboard_entries to anon, authenticated;
