create or replace function public.submit_answer(
  p_room_id uuid,
  p_question_id uuid,
  p_selected_option text,
  p_response_ms integer default 2000
) returns json language plpgsql security definer as $$
declare
  v_player_id uuid;
  v_is_correct boolean;
  v_correct_option text;
  v_points integer := 0;
  v_current_streak integer;
  v_current_score integer;
  v_existing_answer record;
begin
  -- Authenticate
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Get correct option
  select correct_option into v_correct_option
  from public.questions
  where id = p_question_id;

  if v_correct_option is null then
    raise exception 'Question not found';
  end if;

  -- Check correctness
  v_is_correct := (p_selected_option = v_correct_option);

  -- Get current player score/streak from room
  select score, streak into v_current_score, v_current_streak
  from public.room_players
  where room_id = p_room_id and player_id = v_player_id;

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

  -- Calculate points and streak
  if v_is_correct then
    v_current_streak := v_current_streak + 1;
    -- Base 100 points + combo points (max 50 based on streak)
    v_points := 100 + (case when v_current_streak * 10 > 50 then 50 else v_current_streak * 10 end);
    v_current_score := v_current_score + v_points;
  else
    v_current_streak := 0;
    v_points := 0;
  end if;

  -- Insert answer record before score update, so duplicate submits cannot add points twice.
  insert into public.player_answers (
    room_id, question_id, player_id, selected_option, is_correct, response_ms, points_awarded
  ) values (
    p_room_id, p_question_id, v_player_id, p_selected_option, v_is_correct, p_response_ms, v_points
  );

  -- Update player's score and streak in the room
  update public.room_players
  set
    score = v_current_score,
    streak = v_current_streak
  where room_id = p_room_id and player_id = v_player_id;

  -- Return the result
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
