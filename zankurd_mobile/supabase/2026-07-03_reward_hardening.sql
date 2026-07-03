-- ============================================================
-- Odul guvenlik sertlestirmesi (2026-07-03)
--
-- 1. award_coins kaldirildi: istemcinin serbest miktarla coin
--    yazabildigi tek kapi buydu. Yerine amaci belli, sunucu
--    tarifeli claim_* RPC'leri geldi.
-- 2. claim_mission_reward: gorev odulleri sunucu tarifesinden
--    odenir; gorev basina gunde 1, toplam gunde 3 odul.
-- 3. claim_extra_spin: satin alinan ekstra cark haklari sunucuda
--    sayilir, odul sunucuda secilir.
-- 4. claim_tournament_reward: turnuva sampiyonlugu gunde 1 kez.
-- 5. claim_quiz_reward: solo (odasiz) odul gunde 10 ile sinirli.
-- 6. profiles.xp kolonu eklendi (istemci bunu yaziyordu ama kolon
--    yoktu) + dogrudan istemci yazimlari icin artis-clamp trigger'i.
-- 7. room_players: score/streak yalnizca security definer
--    fonksiyonlarca degistirilebilir (is_ready istemciden serbest).
-- ============================================================

-- 0) Istemci modelinin bekledigi ama tabloda hic olmayan dil kolonlari.
--    (Uygulandiktan sonra istemcideki _questionColumns listesine
--    'explanation_ku, explanation_tr' eklenecek.)
alter table public.questions
  add column if not exists explanation_ku text,
  add column if not exists explanation_tr text;

-- 1) Acik kapiyi kapat (canli DB'de zaten yoktu; dosyadaki tanim da silindi).
drop function if exists public.award_coins(integer, text);

-- 2) Gorev odulu: anahtar -> miktar tarifesi sunucudadir.
create or replace function public.claim_mission_reward(p_mission_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_amount integer;
  v_reason text;
  v_today_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_amount := case p_mission_key
    when 'answerCorrect:5' then 30
    when 'answerCorrect:10' then 50
    when 'answerCorrect:15' then 75
    when 'completeQuiz:1' then 25
    when 'completeQuiz:3' then 60
    when 'useWildcard:1' then 20
    when 'useWildcard:2' then 40
    when 'keepStreak:1' then 30
    when 'playCategory:ziman' then 25
    when 'playCategory:cand' then 25
    when 'playCategory:dirok' then 25
    when 'playCategory:edebiyat' then 25
    when 'playCategory:cografya' then 25
    when 'playCategory:muzik' then 25
    else null
  end;
  if v_amount is null then
    raise exception 'Unknown mission key: %', p_mission_key;
  end if;

  v_reason := 'daily_mission:' || p_mission_key || ':'
    || to_char(now(), 'YYYY-MM-DD');

  if exists (
    select 1 from public.coin_transactions
    where player_id = v_uid and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  select count(*) into v_today_count
  from public.coin_transactions
  where player_id = v_uid
    and reason like 'daily_mission:%'
    and created_at >= date_trunc('day', now());
  if v_today_count >= 3 then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, v_amount, v_reason);

  return jsonb_build_object('amount', v_amount, 'already_claimed', false);
end;
$$;

revoke all on function public.claim_mission_reward(text) from public;
grant execute on function public.claim_mission_reward(text) to authenticated;

-- 3) Ekstra cark: hak sayimi ve odul secimi sunucuda.
create or replace function public.claim_extra_spin()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_purchased integer;
  v_used integer;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
  v_reward integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select count(*) into v_purchased
  from public.coin_transactions
  where player_id = v_uid and reason = 'purchase_spin_wheel_extra';

  -- 'daily_spin:extra_purchase' eski istemcilerin yazdigi mirastir.
  select count(*) into v_used
  from public.coin_transactions
  where player_id = v_uid
    and reason in ('extra_spin:server', 'daily_spin:extra_purchase');

  if v_purchased <= v_used then
    return jsonb_build_object('amount', 0, 'no_spins', true);
  end if;

  v_reward := v_rewards[1 + floor(random() * array_length(v_rewards, 1))::int];

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, v_reward, 'extra_spin:server');

  return jsonb_build_object('amount', v_reward, 'no_spins', false);
end;
$$;

revoke all on function public.claim_extra_spin() from public;
grant execute on function public.claim_extra_spin() to authenticated;

-- 4) Turnuva sampiyonlugu: gunde 1 kez, sabit 200.
create or replace function public.claim_tournament_reward()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_reason text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_reason := 'tournament_champion:' || to_char(now(), 'YYYY-MM-DD');

  if exists (
    select 1 from public.coin_transactions
    where player_id = v_uid and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, 200, v_reason);

  return jsonb_build_object('amount', 200, 'already_claimed', false);
end;
$$;

revoke all on function public.claim_tournament_reward() from public;
grant execute on function public.claim_tournament_reward() to authenticated;

-- 5) claim_quiz_reward: solo odul gunde 10 ile sinirli.
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
  v_local_count integer;
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

    -- Solo odul farm'ini sinirla: gunde en fazla 10 odullu solo quiz.
    select count(*) into v_local_count
    from public.coin_transactions
    where player_id = v_player_id
      and reason = 'quiz_complete:local'
      and created_at >= date_trunc('day', now());
    if v_local_count >= 10 then
      return jsonb_build_object(
        'amount', 0,
        'already_claimed', true,
        'daily_limit', true
      );
    end if;
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
  uuid, integer, integer, integer, integer
) from public;
grant execute on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) to authenticated;

-- 6) profiles.xp: kolon + dogrudan istemci yazimlari icin clamp.
alter table public.profiles
  add column if not exists xp integer not null default 0;

create or replace function public.profiles_client_write_guard()
returns trigger
language plpgsql
as $$
begin
  -- security definer fonksiyonlar (postgres olarak calisir) serbesttir;
  -- yalnizca dogrudan REST/istemci guncellemeleri kisitlanir.
  if current_user in ('authenticated', 'anon') then
    if new.xp is distinct from old.xp then
      -- XP tekduze artar; tek guncellemede en fazla +2000.
      new.xp := greatest(
        coalesce(old.xp, 0),
        least(coalesce(new.xp, 0), coalesce(old.xp, 0) + 2000)
      );
    end if;
    -- Coin bakiyesi ve rating hicbir zaman istemciden yazilmaz.
    new.coins := old.coins;
    new.rating := old.rating;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_client_write_guard_trg on public.profiles;
create trigger profiles_client_write_guard_trg
  before update on public.profiles
  for each row
  execute function public.profiles_client_write_guard();

-- 7) room_players: skor/streak yalnizca sunucu fonksiyonlarindan.
create or replace function public.room_players_client_write_guard()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.score is distinct from old.score
          or new.streak is distinct from old.streak) then
    raise exception
      'score/streak can only be changed by server-side functions';
  end if;
  return new;
end;
$$;

drop trigger if exists room_players_client_write_guard_trg
  on public.room_players;
create trigger room_players_client_write_guard_trg
  before update on public.room_players
  for each row
  execute function public.room_players_client_write_guard();
