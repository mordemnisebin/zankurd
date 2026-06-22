-- Matchmaking queue table and matching RPC.
create table if not exists public.matchmaking_queue (
  player_id uuid primary key references public.profiles(id) on delete cascade,
  category_name text not null,
  joined_at timestamp with time zone default now() not null,
  room_id uuid references public.rooms(id) on delete set null
);

-- Enable RLS
alter table public.matchmaking_queue enable row level security;

-- Policies
drop policy if exists "Allow read own matchmaking queue entry" on public.matchmaking_queue;
create policy "Allow read own matchmaking queue entry"
  on public.matchmaking_queue for select
  to authenticated
  using (player_id = auth.uid());

drop policy if exists "Allow insert own matchmaking queue entry" on public.matchmaking_queue;
create policy "Allow insert own matchmaking queue entry"
  on public.matchmaking_queue for insert
  to authenticated
  with check (player_id = auth.uid());

drop policy if exists "Allow delete own matchmaking queue entry" on public.matchmaking_queue;
create policy "Allow delete own matchmaking queue entry"
  on public.matchmaking_queue for delete
  to authenticated
  using (player_id = auth.uid());

-- Matchmaking RPC
create or replace function public.join_matchmaking(
  p_category_name text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_opponent uuid;
  v_room_id uuid;
  v_room_code text;
  v_category_id uuid;
  v_opponent_name text;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Get category_id
  select id into v_category_id
  from public.categories
  where upper(name) = upper(p_category_name)
  limit 1;

  if v_category_id is null then
    select id into v_category_id
    from public.categories
    where slug = 'ziman'
    limit 1;
  end if;

  -- 2. Cleanup old entry
  delete from public.matchmaking_queue where player_id = v_player_id;

  -- 3. Check for waiting player in the same category (excluding self)
  select player_id into v_opponent
  from public.matchmaking_queue
  where category_name = p_category_name
    and player_id <> v_player_id
    and room_id is null
  order by joined_at asc
  limit 1;

  if v_opponent is not null then
    -- Found opponent! Create matchmaking room.
    v_room_code := 'ZK-' || floor(random() * 900 + 100)::text;
    
    insert into public.rooms (code, host_id, category_id, question_count, seconds_per_question, status)
    values (v_room_code, v_opponent, v_category_id, 10, 15, 'lobby')
    returning id into v_room_id;

    -- Add both players
    insert into public.room_players (room_id, player_id, is_ready)
    values 
      (v_room_id, v_opponent, true),
      (v_room_id, v_player_id, true);

    -- Update opponent's row
    update public.matchmaking_queue
    set room_id = v_room_id
    where player_id = v_opponent;

    -- Start the game automatically
    perform public.start_room_game(v_room_id);

    select display_name into v_opponent_name
    from public.profiles
    where id = v_opponent;

    return json_build_object(
      'status', 'matched',
      'room_id', v_room_id,
      'code', v_room_code,
      'opponent_name', coalesce(v_opponent_name, 'Raqîb')
    );
  else
    -- No waiting opponent, join queue
    insert into public.matchmaking_queue (player_id, category_name, room_id)
    values (v_player_id, p_category_name, null);

    return json_build_object(
      'status', 'waiting'
    );
  end if;
end;
$$;

grant execute on function public.join_matchmaking(text) to authenticated;
