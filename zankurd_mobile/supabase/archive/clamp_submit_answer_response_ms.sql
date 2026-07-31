-- Migration: clamp client-reported response_ms in submit_answer.
--
-- quiz_screen.dart now sends the real elapsed time instead of the old
-- hardcoded 2000ms placeholder. Since it comes straight from the client,
-- it must not be trusted as-is (a modified client could send a negative
-- value or an absurdly large one). This re-creates submit_answer with the
-- value clamped to 0-120000ms before it is stored or used.
--
-- Idempotent: safe to run multiple times against the live project via the
-- Supabase SQL editor / management API.

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
