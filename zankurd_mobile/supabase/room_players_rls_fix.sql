-- Fix recursive room_players RLS.
-- Run this in Supabase SQL editor after the base schema is installed.

create or replace function public.is_room_participant(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = auth.uid()
  );
$$;

grant execute on function public.is_room_participant(uuid) to authenticated;

drop policy if exists "Room participants can read rooms" on public.rooms;
drop policy if exists "Players read room membership" on public.room_players;

create policy "Room participants can read rooms"
  on public.rooms for select
  to authenticated
  using (
    host_id = auth.uid()
    or public.is_room_participant(id)
  );

create policy "Players read room membership"
  on public.room_players for select
  to authenticated
  using (
    player_id = auth.uid()
    or public.is_room_participant(room_id)
  );
