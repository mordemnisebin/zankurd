-- Prevent clients from reading answers or writing multiplayer scores directly.

revoke select on public.questions from public, anon, authenticated;
revoke select on public.quiz_eligible_questions from public, anon, authenticated;

create or replace view public.quiz_public_questions as
select
  id,
  category_id,
  prompt,
  option_a,
  option_b,
  option_c,
  option_d,
  question_type,
  image_url,
  difficulty,
  is_approved,
  review_status
from public.questions
where is_approved = true
  and review_status is distinct from 'rejected';

grant select on public.quiz_public_questions to anon, authenticated;

alter table public.player_answers
  drop constraint if exists player_answers_selected_option_check;
alter table public.player_answers
  add constraint player_answers_selected_option_check
  check (selected_option in ('A', 'B', 'C', 'D', 'TIMEOUT'));

drop policy if exists "Players update their own room membership"
  on public.room_players;
drop policy if exists "Hosts can update their own rooms" on public.rooms;

create or replace function public.set_room_ready(
  p_room_id uuid,
  p_is_ready boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.room_players
  set is_ready = coalesce(p_is_ready, false)
  where room_id = p_room_id
    and player_id = auth.uid();

  if not found then
    raise exception 'Player is not in the room';
  end if;
end;
$$;

revoke all on function public.set_room_ready(uuid, boolean) from public, anon;
grant execute on function public.set_room_ready(uuid, boolean) to authenticated;

create or replace function public.get_room_questions(
  p_room_id uuid
) returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = auth.uid()
  ) and not exists (
    select 1
    from public.rooms r
    where r.id = p_room_id
      and r.host_id = auth.uid()
  ) then
    raise exception 'Player is not in the room';
  end if;

  return query
  select jsonb_build_object(
    'id', q.id,
    'category_name', coalesce(c.name, 'Ziman'),
    'prompt', q.prompt,
    'option_a', q.option_a,
    'option_b', q.option_b,
    'option_c', q.option_c,
    'option_d', q.option_d,
    'question_type', q.question_type,
    'image_url', q.image_url,
    'difficulty', q.difficulty
  )
  from public.room_questions rq
  join public.questions q on q.id = rq.question_id
  left join public.categories c on c.id = q.category_id
  where rq.room_id = p_room_id
  order by rq.question_index;
end;
$$;

revoke all on function public.get_room_questions(uuid) from public, anon;
grant execute on function public.get_room_questions(uuid) to authenticated;

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
  v_explanation text;
  v_explanation_ku text;
  v_explanation_tr text;
  v_points integer := 0;
  v_current_streak integer;
  v_current_score integer;
  v_existing_answer record;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  p_selected_option := upper(coalesce(nullif(p_selected_option, ''), 'TIMEOUT'));
  if p_selected_option not in ('A', 'B', 'C', 'D', 'TIMEOUT') then
    raise exception 'Invalid option';
  end if;
  p_response_ms := greatest(0, least(coalesce(p_response_ms, 2000), 120000));

  select
    q.correct_option,
    q.explanation,
    q.explanation_ku,
    q.explanation_tr
  into
    v_correct_option,
    v_explanation,
    v_explanation_ku,
    v_explanation_tr
  from public.room_questions rq
  join public.questions q on q.id = rq.question_id
  join public.rooms r on r.id = rq.room_id
  where rq.room_id = p_room_id
    and rq.question_id = p_question_id
    and r.status = 'active';

  if not found then
    raise exception 'Question is not active in this room';
  end if;

  select score, streak
  into v_current_score, v_current_streak
  from public.room_players
  where room_id = p_room_id
    and player_id = v_player_id
  for update;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select is_correct, points_awarded
  into v_existing_answer
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
      'explanation', v_explanation,
      'explanation_ku', v_explanation_ku,
      'explanation_tr', v_explanation_tr,
      'already_answered', true
    );
  end if;

  v_is_correct := p_selected_option <> 'TIMEOUT'
    and p_selected_option = v_correct_option;
  if v_is_correct then
    v_current_streak := v_current_streak + 1;
    v_points := 100 + least(v_current_streak * 10, 50);
    v_current_score := v_current_score + v_points;
  else
    v_current_streak := 0;
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
  set score = v_current_score,
      streak = v_current_streak
  where room_id = p_room_id
    and player_id = v_player_id;

  return json_build_object(
    'is_correct', v_is_correct,
    'points', v_points,
    'new_score', v_current_score,
    'new_streak', v_current_streak,
    'correct_option', v_correct_option,
    'explanation', v_explanation,
    'explanation_ku', v_explanation_ku,
    'explanation_tr', v_explanation_tr,
    'already_answered', false
  );
end;
$$;

revoke all on function public.submit_answer(uuid, uuid, text, integer)
  from public, anon;
grant execute on function public.submit_answer(uuid, uuid, text, integer)
  to authenticated;
