-- NOT: Bu fonksiyonun guncel surumu 2026-07-03_reward_hardening.sql
-- icindedir (solo odul gunluk limiti eklendi). Bu dosya tarihsel
-- referans olarak durur; yeni degisiklikleri hardening dosyasina yaz.
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
  v_player_id uuid;
  v_existing_id uuid;
  v_room_score integer;
  v_score integer;
  v_correct_count integer;
  v_best_streak integer;
  v_total_questions integer;
  v_amount integer;
  v_reason text;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  v_total_questions := least(greatest(coalesce(p_total_questions, 0), 1), 20);
  v_correct_count := least(
    greatest(coalesce(p_correct_count, 0), 0),
    v_total_questions
  );
  v_best_streak := least(
    greatest(coalesce(p_best_streak, 0), 0),
    v_correct_count
  );
  v_score := least(greatest(coalesce(p_score, 0), 0), v_total_questions * 150);

  if p_room_id is not null then
    select score
      into v_room_score
    from public.room_players
    where room_id = p_room_id
      and player_id = v_player_id;

    if not found then
      raise exception 'Player is not in the room';
    end if;

    v_score := least(v_score, greatest(coalesce(v_room_score, 0), 0));
    v_reason := 'quiz_complete:room=' || p_room_id::text;

    select id
      into v_existing_id
    from public.coin_transactions
    where player_id = v_player_id
      and reason = v_reason
    limit 1;

    if v_existing_id is not null then
      return jsonb_build_object(
        'amount', 0,
        'already_claimed', true
      );
    end if;
  else
    v_reason := 'quiz_complete:local';
  end if;

  v_amount :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_best_streak * 2)
    + (v_score / 80);

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_amount, v_reason);

  return jsonb_build_object(
    'amount', v_amount,
    'already_claimed', false
  );
end;
$$;

revoke all on function public.claim_quiz_reward(
  uuid,
  integer,
  integer,
  integer,
  integer
) from public;
grant execute on function public.claim_quiz_reward(
  uuid,
  integer,
  integer,
  integer,
  integer
) to authenticated;
