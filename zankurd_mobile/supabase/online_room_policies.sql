drop policy if exists "Users insert their own profile" on public.profiles;
drop policy if exists "Players update their own room membership" on public.room_players;

create policy "Users insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "Players update their own room membership"
  on public.room_players for update
  to authenticated
  using (player_id = auth.uid())
  with check (player_id = auth.uid());
