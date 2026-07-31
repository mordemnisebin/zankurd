-- Compatibility definition for the quiz reward RPC. Client metrics are kept
-- in the signature only for old app versions; the award is derived entirely
-- from server-written room rows.

create or replace function public.claim_quiz_reward(
  p_room_id uuid default null,
  p_score integer default 0,
  p_correct_count integer default 0,
  p_best_streak integer default 0,
  p_total_questions integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_room_status text;
  v_room_score integer;
  v_correct_count integer;
  v_total_questions integer;
  v_answer_count integer;
  v_amount integer;
  v_reason text;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;
  if p_room_id is null then
    return jsonb_build_object('amount', 0, 'verification_required', true);
  end if;

  select r.status, greatest(coalesce(rp.score, 0), 0)
  into v_room_status, v_room_score
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id
   and rp.player_id = v_player_id
  where r.id = p_room_id;
  if not found then
    raise exception 'Player is not in the room';
  end if;
  if v_room_status <> 'finished' then
    return jsonb_build_object('amount', 0, 'room_not_finished', true);
  end if;

  select count(*)::integer into v_total_questions
  from public.room_questions
  where room_id = p_room_id;
  select
    count(*)::integer,
    count(*) filter (where pa.is_correct)::integer
  into v_answer_count, v_correct_count
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id
   and rq.question_id = pa.question_id
  where pa.room_id = p_room_id
    and pa.player_id = v_player_id;

  if v_total_questions < 1 or v_answer_count < v_total_questions then
    return jsonb_build_object('amount', 0, 'answers_incomplete', true);
  end if;

  v_reason := 'quiz_complete:room=' || p_room_id::text;
  if exists (
    select 1 from public.coin_transactions
    where player_id = v_player_id and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  v_amount :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_room_score / 80);
  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_amount, v_reason);
  return jsonb_build_object('amount', v_amount, 'already_claimed', false);
end;
$$;

revoke all on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) from public, anon;
grant execute on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) to authenticated;
