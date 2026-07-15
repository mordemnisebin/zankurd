-- Oda süresini 30 saniyeye çıkarır ve doğru cevapta hız bonusunu sunucuda hesaplar.
-- Supabase SQL Editor'da bir kez çalıştırılmalıdır.

alter table public.rooms
  alter column seconds_per_question set default 30;

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
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
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
    'seconds_per_question', v_room.seconds_per_question,
    'category_name', v_room.category_name
  );
end;
$$;

grant execute on function public.join_room_by_code(text) to authenticated;

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
  v_player_id uuid := auth.uid();
  v_is_correct boolean;
  v_correct_option text;
  v_points integer := 0;
  v_current_streak integer;
  v_current_score integer;
  v_existing_answer record;
  v_limit_ms integer;
  v_remaining_ratio numeric;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select greatest(1, coalesce(seconds_per_question, 30)) * 1000
    into v_limit_ms
  from public.rooms
  where id = p_room_id;

  if v_limit_ms is null then
    raise exception 'Room not found';
  end if;

  p_response_ms := greatest(0, least(coalesce(p_response_ms, 2000), v_limit_ms));

  select correct_option into v_correct_option
  from public.questions
  where id = p_question_id;

  if v_correct_option is null then
    raise exception 'Question not found';
  end if;

  v_is_correct := p_selected_option = v_correct_option;

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

  if v_is_correct then
    v_current_streak := v_current_streak + 1;
    v_remaining_ratio := greatest(0, (v_limit_ms - p_response_ms)::numeric / v_limit_ms);
    v_points := 100 + round(v_remaining_ratio * 100)::integer
      + least(v_current_streak * 10, 50);
    v_current_score := v_current_score + v_points;
  else
    v_current_streak := 0;
  end if;

  insert into public.player_answers (
    room_id, question_id, player_id, selected_option,
    is_correct, response_ms, points_awarded
  ) values (
    p_room_id, p_question_id, v_player_id, p_selected_option,
    v_is_correct, p_response_ms, v_points
  );

  update public.room_players
  set score = v_current_score, streak = v_current_streak
  where room_id = p_room_id and player_id = v_player_id;

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
