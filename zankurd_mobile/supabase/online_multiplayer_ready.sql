-- ZanKurd online multiplayer readiness patch.
-- Run this in the Supabase SQL editor after the base schema/question bank is installed.
--
-- It fixes two release-blocking issues:
-- 1. Joining by room code must not require clients to SELECT a private room
--    before they are a participant.
-- 2. Room start/finish and answer submission RPCs must exist for live play.

create or replace function public.join_room_by_code(
  p_code text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_room record;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select
    r.id,
    r.code,
    r.question_count,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where upper(r.code) = upper(trim(p_code))
    and r.status = 'lobby'
  limit 1;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_player_id, false)
  on conflict (room_id, player_id) do update
  set is_ready = public.room_players.is_ready;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'question_count', v_room.question_count,
    'category_name', v_room.category_name
  );
end;
$$;

grant execute on function public.join_room_by_code(text) to authenticated;

create or replace function public.start_room_game(
  p_room_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
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

grant execute on function public.start_room_game(uuid) to authenticated;

create or replace function public.finish_room_game(
  p_room_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
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

grant execute on function public.finish_room_game(uuid) to authenticated;

create or replace function public.submit_answer(
  p_room_id uuid,
  p_question_id uuid,
  p_selected_option text,
  p_response_ms integer default 2000
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_is_correct boolean;
  v_correct_option text;
  v_points integer := 0;
  v_current_streak integer;
  v_current_score integer;
  v_existing_answer record;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Client-reported response time is not trustworthy input; clamp it to a
  -- sane range (0-120s) so a manipulated/garbage value can't corrupt
  -- analytics or overflow downstream consumers.
  p_response_ms := greatest(0, least(coalesce(p_response_ms, 2000), 120000));

  select correct_option into v_correct_option
  from public.questions
  where id = p_question_id;

  if v_correct_option is null then
    raise exception 'Question not found';
  end if;

  v_is_correct := (p_selected_option = v_correct_option);

  select score, streak into v_current_score, v_current_streak
  from public.room_players
  where room_id = p_room_id
    and player_id = v_player_id;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select is_correct, points_awarded into v_existing_answer
  from public.player_answers
  where room_id = p_room_id
    and question_id = p_question_id
    and player_id = v_player_id;

  if found then
    return json_build_object(
      'is_correct', v_existing_answer.is_correct,
      'points', 0,
      'new_score', v_current_score,
      'new_streak', v_current_streak,
      'correct_option', v_correct_option,
      'already_answered', true
    );
  end if;

  if v_is_correct then
    v_current_streak := v_current_streak + 1;
    v_points := 100 + least(v_current_streak * 10, 50);
    v_current_score := v_current_score + v_points;
  else
    v_current_streak := 0;
    v_points := 0;
  end if;

  insert into public.player_answers (
    room_id,
    question_id,
    player_id,
    selected_option,
    is_correct,
    response_ms,
    points_awarded
  ) values (
    p_room_id,
    p_question_id,
    v_player_id,
    p_selected_option,
    v_is_correct,
    p_response_ms,
    v_points
  );

  update public.room_players
  set
    score = v_current_score,
    streak = v_current_streak
  where room_id = p_room_id
    and player_id = v_player_id;

  return json_build_object(
    'is_correct', v_is_correct,
    'points', v_points,
    'new_score', v_current_score,
    'new_streak', v_current_streak,
    'correct_option', v_correct_option,
    'already_answered', false
  );
end;
$$;

grant execute on function public.submit_answer(uuid, uuid, text, integer) to authenticated;

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
