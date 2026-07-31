create or replace function public.start_room_game(
  p_room_id uuid
) returns json language plpgsql security definer as $$
declare
  v_player_id uuid;
  v_room public.rooms%rowtype;
  v_question_count integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id;

  if not found then
    raise exception 'Room not found';
  end if;

  if v_room.host_id <> v_player_id then
    raise exception 'Only the host can start this room';
  end if;

  if not exists (
    select 1
    from public.room_questions
    where room_id = p_room_id
  ) then
    insert into public.room_questions (
      room_id,
      question_id,
      question_index,
      started_at
    )
    select
      p_room_id,
      picked.id,
      row_number() over (order by picked.random_order)::integer - 1,
      case
        when row_number() over (order by picked.random_order) = 1 then now()
        else null
      end
    from (
      select q.id, random() as random_order
      from public.questions q
      where q.is_approved = true
        and (v_room.category_id is null or q.category_id = v_room.category_id)
      order by random_order
      limit v_room.question_count
    ) picked;
  end if;

  select count(*)::integer into v_question_count
  from public.room_questions
  where room_id = p_room_id;

  if v_question_count = 0 then
    raise exception 'No approved questions available for this room';
  end if;

  update public.rooms
  set
    status = 'active',
    current_question_index = 0,
    started_at = coalesce(started_at, now())
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$$;

create or replace function public.finish_room_game(
  p_room_id uuid
) returns json language plpgsql security definer as $$
declare
  v_player_id uuid;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.room_players
    where room_id = p_room_id
      and player_id = v_player_id
  ) then
    raise exception 'Player is not in the room';
  end if;

  update public.rooms
  set
    status = 'finished',
    finished_at = coalesce(finished_at, now())
  where id = p_room_id;

  return json_build_object('status', 'finished');
end;
$$;

drop policy if exists "Room participants can read room questions" on public.room_questions;

create policy "Room participants can read room questions"
  on public.room_questions for select
  to authenticated
  using (
    exists (
      select 1
      from public.room_players
      where room_players.room_id = room_questions.room_id
        and room_players.player_id = auth.uid()
    )
    or exists (
      select 1
      from public.rooms
      where rooms.id = room_questions.room_id
        and rooms.host_id = auth.uid()
    )
  );

grant execute on function public.start_room_game(uuid) to authenticated;
grant execute on function public.finish_room_game(uuid) to authenticated;
