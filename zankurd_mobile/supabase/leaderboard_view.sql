drop view if exists public.leaderboard_entries;

create view public.leaderboard_entries as
select
  row_number() over (order by coalesce(p.xp, 0) desc)::integer as rank,
  p.id as player_id,
  coalesce(p.display_name, 'Oyuncu') as display_name,
  coalesce(p.xp, 0)::integer as total_score,
  0::integer as best_streak,
  0::integer as rooms_played,
  p.avatar_icon,
  p.avatar_color,
  p.avatar_url,
  p.avatar_frame,
  p.showcase_title
from public.profiles p;

grant select on public.leaderboard_entries to anon, authenticated;
