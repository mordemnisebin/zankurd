-- ZanKurd production schema baseline; ordering timestamp only.
-- Source: verified production logical schema backup, public application schema.
-- Platform normalization: pg_dump \restrict/\unrestrict wrappers removed.
-- Platform normalization: public schema CREATE/OWNER/COMMENT statements removed because Supabase provides public; application objects are unchanged.
-- No application table, column, type, function, index, constraint, policy, trigger, grant, SECURITY DEFINER or search_path clause is intentionally omitted.

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--




--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--



--
-- Name: match_mode; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.match_mode AS ENUM (
    'practice',
    'private_room',
    'random_match',
    'daily',
    'tournament'
);


ALTER TYPE public.match_mode OWNER TO postgres;

--
-- Name: room_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.room_status AS ENUM (
    'lobby',
    'active',
    'reveal',
    'finished',
    'cancelled'
);


ALTER TYPE public.room_status OWNER TO postgres;

--
-- Name: accept_friend_request(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.accept_friend_request(p_request_id uuid) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_from_user_id UUID;
  v_from_user_name TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  -- Get request and verify it's for current user
  SELECT from_user_id, from_user_name INTO v_from_user_id, v_from_user_name
  FROM friend_requests
  WHERE id = p_request_id AND to_user_id = v_user_id AND status = 'pending';

  IF v_from_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Friend request not found or already processed'::TEXT;
    RETURN;
  END IF;

  -- Create bidirectional friendship
  INSERT INTO friends (user_id, friend_id, friend_name)
  VALUES
    (v_user_id, v_from_user_id, v_from_user_name),
    (v_from_user_id, v_user_id, 'Player')
  ON CONFLICT DO NOTHING;

  -- Update request status
  UPDATE friend_requests SET status = 'accepted' WHERE id = p_request_id;

  RETURN QUERY SELECT TRUE, 'Friend request accepted'::TEXT;
END;
$$;


ALTER FUNCTION public.accept_friend_request(p_request_id uuid) OWNER TO postgres;

--
-- Name: add_friend(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_friend(p_friend_id uuid, p_friend_name text) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  IF v_user_id = p_friend_id THEN
    RETURN QUERY SELECT FALSE, 'Cannot add yourself as friend'::TEXT;
    RETURN;
  END IF;

  -- Check if already friends
  IF EXISTS (
    SELECT 1 FROM friends
    WHERE (user_id = v_user_id AND friend_id = p_friend_id)
       OR (user_id = p_friend_id AND friend_id = v_user_id)
  ) THEN
    RETURN QUERY SELECT FALSE, 'Already friends'::TEXT;
    RETURN;
  END IF;

  -- Create friend request
  INSERT INTO friend_requests (from_user_id, from_user_name, to_user_id, status)
  VALUES (v_user_id, 'Player', p_friend_id, 'pending')
  ON CONFLICT (from_user_id, to_user_id) DO NOTHING;

  RETURN QUERY SELECT TRUE, 'Friend request sent'::TEXT;
END;
$$;


ALTER FUNCTION public.add_friend(p_friend_id uuid, p_friend_name text) OWNER TO postgres;

--
-- Name: advance_room_question(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.advance_room_question(p_room_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_next integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select count(*)::integer into v_count
  from public.room_questions
  where room_id = p_room_id;

  if v_count < 1 then
    raise exception 'Room has no questions';
  end if;

  -- Tavan `v_count`tur, `v_count - 1` DEĞİL.
  --
  -- İlk yazımda `v_count - 1`de durduruluyordu ve bu, ev sahibini son
  -- soruda kilitliyordu: istemci maçın bittiğini "indeks soru sayısına
  -- ulaştı" diye anlıyor (`_syncToQuestionIndex`), yani son sorudan sonra
  -- indeksin bir kez daha artması gerekiyor. Sınır bir eksik olunca ev
  -- sahibinde "Biqedîne" hiç etkinleşmiyordu — katılan sonuç ekranını
  -- görüyor, ev sahibi son soruda donup kalıyordu (2026-08-01, aynı canlı
  -- denemede, ilk düzeltmeden hemen sonra görüldü).
  --
  -- Sınır yine de gerekli: sınırsız artış, `enforce_current_room_question`
  -- hiçbir cevabı kabul etmediği hâlde odayı süresiz "etkin" tutardı.
  -- `v_count`ta durmak ikisini birden sağlıyor — `finish_room_game`
  -- indeksin `>= v_count - 1` olmasını istiyor, `v_count` bunu karşılıyor.
  update public.rooms r
     set current_question_index =
           least(coalesce(r.current_question_index, 0) + 1, v_count)
   where r.id = p_room_id
     and r.host_id = v_uid
     and r.status = 'active'
  returning r.current_question_index into v_next;

  if v_next is null then
    raise exception 'Only the active room host can advance the question';
  end if;

  return v_next;
end;
$$;


ALTER FUNCTION public.advance_room_question(p_room_id uuid) OWNER TO postgres;

--
-- Name: advance_tournament(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.advance_tournament(p_tournament_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_round int;
  v_pending int;
  v_winners uuid[];
  v_i int;
  v_slot int := 0;
  v_hours int;
begin
  select round_hours into v_hours from public.tournaments
   where id = p_tournament_id;

  select max(round) into v_round from public.tournament_matches
   where tournament_id = p_tournament_id;
  if v_round is null then return; end if;

  select count(*) into v_pending from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and status <> 'completed';
  if v_pending > 0 then return; end if;

  select array_agg(winner_id order by slot) into v_winners
    from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and winner_id is not null;

  if v_winners is null or array_length(v_winners, 1) <= 1 then
    update public.tournaments
       set status = 'finished',
           finished_at = now(),
           champion_id = case
             when v_winners is null then null else v_winners[1] end
     where id = p_tournament_id;
    return;
  end if;

  v_i := 1;
  while v_i <= array_length(v_winners, 1) loop
    insert into public.tournament_matches (
      tournament_id, round, slot, player_one, player_two, deadline
    ) values (
      p_tournament_id, v_round + 1, v_slot,
      v_winners[v_i], v_winners[v_i + 1],
      now() + make_interval(hours => coalesce(v_hours, 24))
    );
    v_slot := v_slot + 1;
    v_i := v_i + 2;
  end loop;

  update public.tournament_matches
     set status = 'completed', winner_id = player_one
   where tournament_id = p_tournament_id
     and round = v_round + 1
     and player_two is null;
end;
$$;


ALTER FUNCTION public.advance_tournament(p_tournament_id uuid) OWNER TO postgres;

--
-- Name: assign_player_tag(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.assign_player_tag() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.player_tag is null or length(trim(new.player_tag)) = 0 then
    new.player_tag := public.generate_player_tag();
  end if;
  return new;
end;
$$;


ALTER FUNCTION public.assign_player_tag() OWNER TO postgres;

--
-- Name: award_spin_coins(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.award_spin_coins() RETURNS TABLE(success boolean, reward_amount integer, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_today date := current_date;
  v_spin_id uuid;
  v_reward integer;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
begin
  if v_user_id is null then
    return query select false, 0, 'Authenticated user required'::text;
    return;
  end if;

  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    return query select false, 0, 'Profile missing'::text;
    return;
  end if;

  v_reward := v_rewards[
    (
      (extract(day from v_today)::integer
        + extract(month from v_today)::integer * 31)
      % array_length(v_rewards, 1)
    ) + 1
  ];

  insert into public.spin_wheel_history (user_id, spin_date, reward_amount)
  values (v_user_id, v_today, v_reward)
  on conflict (user_id, spin_date) do nothing
  returning id into v_spin_id;

  if v_spin_id is null then
    return query select false, 0, 'Already spun today'::text;
    return;
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_user_id, v_reward, 'spin_wheel');

  return query select true, v_reward, 'Spin awarded successfully'::text;
end;
$$;


ALTER FUNCTION public.award_spin_coins() OWNER TO postgres;

--
-- Name: award_xp_delta(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.award_xp_delta(p_delta integer) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_uid uuid := auth.uid();
  v_xp integer := 0;
  v_has_xp boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if to_regclass('public.profiles') is null then
    return 0;
  end if;

  select exists (
    select 1
    from pg_catalog.pg_attribute
    where attrelid = to_regclass('public.profiles')
      and attname = 'xp'
      and not attisdropped
  ) into v_has_xp;

  if not v_has_xp then
    return 0;
  end if;

  execute
    'select coalesce(xp, 0)::integer from public.profiles where id = $1'
    into v_xp
    using v_uid;

  return coalesce(v_xp, 0);
end;
$_$;


ALTER FUNCTION public.award_xp_delta(p_delta integer) OWNER TO postgres;

--
-- Name: block_player(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.block_player(p_blocked_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_blocked_id = auth.uid() then
    raise exception 'cannot_block_self';
  end if;
  insert into public.blocked_users (blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict do nothing;
end;
$$;


ALTER FUNCTION public.block_player(p_blocked_id uuid) OWNER TO postgres;

--
-- Name: can_spin_today(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.can_spin_today() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select auth.uid() is not null
    and not exists (
      select 1
      from public.spin_wheel_history
      where user_id = auth.uid()
        and spin_date = current_date
    );
$$;


ALTER FUNCTION public.can_spin_today() OWNER TO postgres;

--
-- Name: chat_message_is_clean(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.chat_message_is_clean(p_text text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO 'public'
    AS $$
declare
  v_norm text;
  v_word text;
  v_blocked text[] := array[
    -- 'got' BİLEREK YOK: Kurmancîde "dedi" demek. Aynı gerekçeyle
    -- 'kere', 'heywan', 'gu' ve iki harfliler de dışarıda. İstemci
    -- tarafındaki liste ile aynı (chat_moderation_policy.dart).
    'orospu','pic','yavsak','sikeyim','siktir','amk','gavat',
    'serefsiz','ibne','pezevenk','yarrak','amina','sikik',
    'qehpik','qehbe','kerbeso','beseref'
  ];
begin
  if p_text is null or length(trim(p_text)) = 0 then
    return false;
  end if;
  if length(p_text) > 240 then
    return false;
  end if;
  -- Bağlantı: reklam ve oltalama yüzeyi.
  if p_text ~* '(https?://|www\.|[a-z0-9-]+\.(com|net|org|io|me|tk|ru|xyz))' then
    return false;
  end if;

  -- İstemcideki `_normalize` ile aynı sadeleştirme: aksan ve rakam
  -- kaçamakları düz hâle indirgenir.
  v_norm := lower(p_text);
  v_norm := translate(v_norm, 'ışğüöçîêû01345@', 'isguocieuoiesa');
  v_norm := regexp_replace(v_norm, '[^a-z]+', ' ', 'g');

  foreach v_word in array v_blocked loop
    if (' ' || v_norm || ' ') like ('% ' || v_word || ' %') then
      return false;
    end if;
  end loop;

  return true;
end;
$$;


ALTER FUNCTION public.chat_message_is_clean(p_text text) OWNER TO postgres;

--
-- Name: claim_contest_reward(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.claim_contest_reward(p_contest_id uuid) RETURNS TABLE(claimed boolean, rank_reward integer, badge_awarded text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  return query select false, 0::int, null::text;
end;
$$;


ALTER FUNCTION public.claim_contest_reward(p_contest_id uuid) OWNER TO postgres;

--
-- Name: claim_daily_spin(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.claim_daily_spin() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_spin_id uuid;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
  v_reward integer;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  v_reward := v_rewards[1 + floor(random() * array_length(v_rewards, 1))::int];

  insert into public.spin_wheel_history (user_id, spin_date, reward_amount)
  values (v_player_id, current_date, v_reward)
  on conflict (user_id, spin_date) do nothing
  returning id into v_spin_id;

  if v_spin_id is null then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_reward, 'daily_spin:server');

  return jsonb_build_object(
    'amount', v_reward,
    'already_claimed', false
  );
end;
$$;


ALTER FUNCTION public.claim_daily_spin() OWNER TO postgres;

--
-- Name: claim_extra_spin(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.claim_extra_spin() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  select count(*) into v_purchased
  from public.shop_purchases
  where player_id = v_uid
    and item_id = 'spin_wheel_extra';

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


ALTER FUNCTION public.claim_extra_spin() OWNER TO postgres;

--
-- Name: claim_mission_reward(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.claim_mission_reward(p_mission_key text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Görev ilerlemesi çevrimdışı cihazda tutulur; yalnız anahtar gönderen bir
  -- istemcinin görevi gerçekten yaptığını sunucu kanıtlayamaz. Eski istemci
  -- sözleşmesini bozmadan coin yazımını kapat. Yeni istemci görevi XP olarak
  -- gösterir.
  return jsonb_build_object(
    'amount', 0,
    'verification_required', true,
    'mission_key', p_mission_key
  );
end;
$$;


ALTER FUNCTION public.claim_mission_reward(p_mission_key text) OWNER TO postgres;

--
-- Name: claim_quiz_reward(uuid, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.claim_quiz_reward(p_room_id uuid DEFAULT NULL::uuid, p_score integer DEFAULT 0, p_correct_count integer DEFAULT 0, p_best_streak integer DEFAULT 0, p_total_questions integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
    return jsonb_build_object(
      'amount', 0,
      'verification_required', true
    );
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
    where player_id = v_player_id
      and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  v_amount :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_room_score / 80);

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_amount, v_reason);

  return jsonb_build_object(
    'amount', v_amount,
    'already_claimed', false
  );
end;
$$;


ALTER FUNCTION public.claim_quiz_reward(p_room_id uuid, p_score integer, p_correct_count integer, p_best_streak integer, p_total_questions integer) OWNER TO postgres;

--
-- Name: claim_tournament_reward(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.claim_tournament_reward() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_tournament uuid;
  v_reason text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  select t.id into v_tournament
  from public.tournaments t
  where t.status = 'finished'
    and t.champion_id = v_uid
    and not exists (
      select 1
      from public.coin_transactions ct
      where ct.player_id = v_uid
        and ct.reason = 'tournament_champion:' || t.id::text
    )
  order by t.finished_at desc
  limit 1;

  if v_tournament is null then
    return jsonb_build_object('amount', 0, 'already_claimed', false);
  end if;

  v_reason := 'tournament_champion:' || v_tournament::text;
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


ALTER FUNCTION public.claim_tournament_reward() OWNER TO postgres;

--
-- Name: cleanup_stale_rooms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cleanup_stale_rooms() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  -- Oyuncu cevapları / oda oyuncuları FK ile odaya bağlıysa önce onlar.
  delete from public.player_answers
  where room_id in (
    select id from public.rooms
    where created_at < now() - interval '24 hours'
      and coalesce(status, '') <> 'finished'
  );

  delete from public.room_players
  where room_id in (
    select id from public.rooms
    where created_at < now() - interval '24 hours'
      and coalesce(status, '') <> 'finished'
  );

  delete from public.rooms
  where created_at < now() - interval '24 hours'
    and coalesce(status, '') <> 'finished';

  delete from public.matchmaking_queue
  where created_at < now() - interval '10 minutes';
end;
$$;


ALTER FUNCTION public.cleanup_stale_rooms() OWNER TO postgres;

--
-- Name: delete_my_account(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_my_account() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $_$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.favorite_questions
  where player_id = v_user_id;

  delete from public.coin_transactions
  where player_id = v_user_id;

  if to_regclass('public.questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.questions')
         and attname = 'created_by'
         and not attisdropped
     ) then
    execute
      'update public.questions set created_by = null where created_by = $1'
      using v_user_id;
  end if;

  if to_regclass('public.suggested_questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.suggested_questions')
         and attname = 'reviewed_by'
         and not attisdropped
     ) then
    execute
      'update public.suggested_questions set reviewed_by = null '
      || 'where reviewed_by = $1'
      using v_user_id;
  end if;

  update public.question_reports
  set reporter_id = null
  where reporter_id = v_user_id;

  delete from public.player_answers
  where player_id = v_user_id;

  delete from public.rooms
  where host_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = v_user_id::text;

  delete from auth.users
  where id = v_user_id;

  return json_build_object('deleted', true);
end;
$_$;


ALTER FUNCTION public.delete_my_account() OWNER TO postgres;

--
-- Name: enforce_chat_moderation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.enforce_chat_moderation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.chat_message_is_clean(new.text) then
    raise exception 'chat_message_rejected';
  end if;

  -- Yalnız odanın üyesi yazabilir.
  if not exists (
    select 1 from public.room_players rp
     where rp.room_id = new.room_id and rp.player_id = v_uid
  ) then
    raise exception 'not_a_room_member';
  end if;

  new.sender_id := v_uid;
  new.sender_name := coalesce(
    (select p.display_name from public.profiles p where p.id = v_uid),
    new.sender_name
  );
  new.created_at := now();
  new.text := trim(new.text);
  return new;
end;
$$;


ALTER FUNCTION public.enforce_chat_moderation() OWNER TO postgres;

--
-- Name: enforce_current_room_question(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.enforce_current_room_question() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is not null and new.player_id is distinct from auth.uid() then
    raise exception 'Answer player does not match authenticated user';
  end if;

  if not exists (
    select 1
    from public.room_questions rq
    join public.rooms r on r.id = rq.room_id
    where rq.room_id = new.room_id
      and rq.question_id = new.question_id
      and rq.question_index = r.current_question_index
      and r.status = 'active'
  ) then
    raise exception 'Question is not the current active room question';
  end if;
  return new;
end;
$$;


ALTER FUNCTION public.enforce_current_room_question() OWNER TO postgres;

--
-- Name: enforce_display_name_policy(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.enforce_display_name_policy() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  -- Yalnız ad GERÇEKTEN değiştiğinde denetle. Aksi hâlde ada dokunmayan
  -- her profil güncellemesi (avatar rengi, XP, oyuncu kodu…) eski bir
  -- kayıt yüzünden reddedilirdi.
  if tg_op = 'UPDATE'
     and new.display_name is not distinct from old.display_name then
    return new;
  end if;

  if new.display_name is null then
    return new;
  end if;

  if not public.zk_display_name_is_clean(new.display_name) then
    raise exception 'display_name rejected by moderation policy'
      using errcode = 'check_violation';
  end if;

  new.display_name := btrim(new.display_name);
  return new;
end;
$$;


ALTER FUNCTION public.enforce_display_name_policy() OWNER TO postgres;

--
-- Name: finalize_weekly_league(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.finalize_weekly_league(p_week date DEFAULT NULL::date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_week date := coalesce(p_week, public.league_week_start(now() - interval '1 day'));
  v_from timestamptz := (v_week::timestamptz at time zone 'UTC');
  v_to   timestamptz := v_from + interval '7 days';
  v_count int := 0;
begin
  insert into public.league_weeks (week_start, status)
  values (v_week, 'finalizing')
  on conflict (week_start) do update set status = 'finalizing';

  -- Önceki hafta kademesi (yoksa bronz)
  create temporary table if not exists _prev_tier on commit drop as
  select player_id, tier
  from public.league_memberships
  where week_start = (v_week - 7);

  -- Bu haftanın skorları
  create temporary table if not exists _week_scores on commit drop as
  select
    rp.player_id,
    coalesce(sum(rp.score), 0)::bigint as weekly_score
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where r.status = 'finished'
    and r.finished_at >= v_from
    and r.finished_at < v_to
    and rp.player_id is not null
  group by rp.player_id;

  -- Sıralama + kademe yaz
  delete from public.league_memberships where week_start = v_week;

  insert into public.league_memberships (
    week_start, player_id, tier, weekly_score, weekly_rank,
    previous_tier, promoted, relegated
  )
  select
    v_week,
    s.player_id,
    public.league_tier_for_rank(s.rnk::int),
    s.weekly_score,
    s.rnk::int,
    coalesce(p.tier, 'bronz'),
    public.league_tier_for_rank(s.rnk::int) = 'zer' and coalesce(p.tier, 'bronz') <> 'zer'
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'bronz',
    public.league_tier_for_rank(s.rnk::int) = 'bronz' and coalesce(p.tier, 'bronz') in ('zer', 'ziv')
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'zer'
  from (
    select
      player_id,
      weekly_score,
      rank() over (order by weekly_score desc, player_id) as rnk
    from _week_scores
  ) s
  left join _prev_tier p on p.player_id = s.player_id;

  get diagnostics v_count = row_count;

  update public.league_weeks
  set status = 'closed', finalized_at = now()
  where week_start = v_week;

  return jsonb_build_object(
    'week_start', v_week,
    'players', v_count,
    'status', 'closed'
  );
end;
$$;


ALTER FUNCTION public.finalize_weekly_league(p_week date) OWNER TO postgres;

--
-- Name: finish_room_game(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.finish_room_game(p_room_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_status text;
  v_index integer;
  v_question_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.status, r.current_question_index
  into v_status, v_index
  from public.rooms r
  where r.id = p_room_id
    and r.host_id = v_uid
  for update;

  if not found then
    raise exception 'Only the room host can finish the game';
  end if;
  select count(*)::integer into v_question_count
  from public.room_questions
  where room_id = p_room_id;
  if v_status = 'finished' then
    return json_build_object('status', 'finished');
  end if;
  if v_status <> 'active'
     or v_question_count < 1
     or coalesce(v_index, -1) < v_question_count - 1 then
    raise exception 'Room is not ready to finish';
  end if;

  update public.rooms
  set status = 'finished',
      finished_at = coalesce(finished_at, now())
  where id = p_room_id;
  return json_build_object('status', 'finished');
end;
$$;


ALTER FUNCTION public.finish_room_game(p_room_id uuid) OWNER TO postgres;

--
-- Name: freeze_player_tag(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.freeze_player_tag() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if old.player_tag is not null and new.player_tag is distinct from old.player_tag then
    new.player_tag := old.player_tag;
  end if;
  return new;
end;
$$;


ALTER FUNCTION public.freeze_player_tag() OWNER TO postgres;

--
-- Name: generate_player_tag(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_player_tag() RETURNS text
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  -- Sesli harf ve karışan karakter yok: 0/O, 1/I/L, A/E/I/O/U dışarıda.
  v_alphabet constant text := '23456789BCDFGHJKMNPQRSTVWXYZ';
  v_length   constant int  := 4;
  v_candidate text;
  v_attempt   int := 0;
begin
  loop
    v_attempt := v_attempt + 1;
    v_candidate := '';
    for i in 1..v_length loop
      v_candidate := v_candidate ||
        substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;

    exit when not exists (
      select 1 from public.profiles where player_tag = v_candidate
    );

    -- Havuz dolmadıkça buraya gelinmez; yine de sonsuz döngü olmasın.
    if v_attempt > 50 then
      raise exception 'player_tag üretilemedi (50 deneme)';
    end if;
  end loop;

  return v_candidate;
end;
$$;


ALTER FUNCTION public.generate_player_tag() OWNER TO postgres;

--
-- Name: get_contest_leaderboard(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_contest_leaderboard(p_contest_id uuid, p_limit integer DEFAULT 10) RETURNS TABLE(user_id uuid, display_name text, score integer, correct_count integer, rank integer, finished_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.user_id, p.display_name, ce.score, ce.correct_count, ce.rank, ce.finished_at
  FROM contest_entries ce
  LEFT JOIN profiles p ON p.id = ce.user_id
  WHERE ce.contest_id = p_contest_id AND ce.finished_at IS NOT NULL
  ORDER BY ce.rank NULLS LAST, ce.score DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION public.get_contest_leaderboard(p_contest_id uuid, p_limit integer) OWNER TO postgres;

--
-- Name: get_leaderboard(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_leaderboard(p_days integer DEFAULT '-1'::integer, p_limit integer DEFAULT 10) RETURNS TABLE(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(rp.score), 0),
    coalesce(max(rp.streak), 0),
    count(distinct rp.room_id),
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
  group by
    rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  order by coalesce(sum(rp.score), 0) desc,
    coalesce(max(rp.streak), 0) desc,
    count(distinct rp.room_id) desc
  limit least(greatest(p_limit, 1), 100);
$$;


ALTER FUNCTION public.get_leaderboard(p_days integer, p_limit integer) OWNER TO postgres;

--
-- Name: get_my_league_state(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_my_league_state() RETURNS TABLE(week_start date, tier text, weekly_score bigint, weekly_rank integer, previous_tier text, promoted boolean, relegated boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    m.week_start,
    m.tier,
    m.weekly_score,
    m.weekly_rank,
    m.previous_tier,
    m.promoted,
    m.relegated
  from public.league_memberships m
  where m.player_id = auth.uid()
  order by m.week_start desc
  limit 1;
$$;


ALTER FUNCTION public.get_my_league_state() OWNER TO postgres;

--
-- Name: get_room_questions(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_room_questions(p_room_id uuid) RETURNS SETOF jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


ALTER FUNCTION public.get_room_questions(p_room_id uuid) OWNER TO postgres;

--
-- Name: get_today_contest(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_today_contest() RETURNS TABLE(id uuid, day_key date, theme_name_ku text, theme_description_ku text, category text, difficulty_min integer, difficulty_max integer, participation_reward integer, rank1_reward integer, rank2_reward integer, rank3_reward integer, question_count integer)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id, c.day_key, c.theme_name_ku, c.theme_description_ku, c.category,
    c.difficulty_min, c.difficulty_max, c.participation_reward,
    c.rank1_reward, c.rank2_reward, c.rank3_reward, c.question_count
  FROM contests c
  WHERE c.day_key = CURRENT_DATE
  LIMIT 1;
END;
$$;


ALTER FUNCTION public.get_today_contest() OWNER TO postgres;

--
-- Name: get_tournament_bracket(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_tournament_bracket() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user uuid := auth.uid();
  v_tournament public.tournaments;
  v_rounds jsonb;
  v_current_round int;
  v_max_round int;
  v_eliminated boolean;
  v_status text;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  -- Ekran her açıldığında zamanı gelmiş işler yürütülür: süresi dolan
  -- maçlar hükmen kapanır, dolmayı bekleyen turnuvalar eldeki oyuncularla
  -- başlar. Ayrı bir zamanlayıcı gerekmez.
  perform public.resolve_expired_tournament_matches();
  perform public.start_due_tournaments();

  select t.* into v_tournament
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_user
   order by t.opened_at desc
   limit 1;

  if not found then
    return null;
  end if;

  select jsonb_agg(r order by r_round)
    into v_rounds
    from (
      select m.round as r_round,
             jsonb_build_object(
               'round', m.round,
               'matches', jsonb_agg(
                 jsonb_build_object(
                   'id', m.id,
                   'playerOneId', coalesce(m.player_one::text, ''),
                   'playerOneName', coalesce(e1.display_name, '—'),
                   'playerTwoId', coalesce(m.player_two::text, ''),
                   'playerTwoName', coalesce(e2.display_name, '—'),
                   'playerOneScore', coalesce(m.score_one, 0),
                   'playerTwoScore', coalesce(m.score_two, 0),
                   'status', m.status,
                   'winnerId', coalesce(m.winner_id::text, ''),
                   'deadline', m.deadline
                 ) order by m.slot
               )
             ) as r
        from public.tournament_matches m
        left join public.tournament_entries e1
               on e1.tournament_id = m.tournament_id
              and e1.player_id = m.player_one
        left join public.tournament_entries e2
               on e2.tournament_id = m.tournament_id
              and e2.player_id = m.player_two
       where m.tournament_id = v_tournament.id
       group by m.round
    ) rounds;

  -- `currentRound` istemcinin "benim maçım hangi turda" sorusunu yanıtlar
  -- ve tur adını (Son 16 / Çeyrek / Yarı / Final) seçer. Gönderilmezse 0'a
  -- düşer: ikinci turdaki oyuncu birinci turda aranır, maçı hiç bulunamaz
  -- ve ekran yanlış tur adını yazar. Sıfır tabanlıdır — istemci onu dizin
  -- olarak kullanır.
  select min(m.round) - 1
    into v_current_round
    from public.tournament_matches m
   where m.tournament_id = v_tournament.id
     and m.status <> 'completed'
     and v_user in (m.player_one, m.player_two);

  select max(m.round) into v_max_round
    from public.tournament_matches m
   where m.tournament_id = v_tournament.id;

  -- Açık maçı yoksa: ya elendi ya da kupa bitti. Elenmeyi turnuvanın
  -- bitmesine bağlamak yanlıştı — birinci turda kaybeden oyuncu, kupa
  -- sürerken hâlâ "maçın var" görüyordu.
  v_eliminated := v_current_round is null and exists (
    select 1 from public.tournament_matches m
     where m.tournament_id = v_tournament.id
       and m.status = 'completed'
       and v_user in (m.player_one, m.player_two)
       and coalesce(m.winner_id, '00000000-0000-0000-0000-000000000000'::uuid)
           <> v_user
  );

  if v_tournament.champion_id = v_user then
    v_status := 'won';
  elsif v_eliminated then
    v_status := 'eliminated';
  elsif v_tournament.status = 'finished' then
    v_status := 'eliminated';
  else
    v_status := 'active';
  end if;

  return jsonb_build_object(
    'tournamentId', v_tournament.id,
    'userId', v_user,
    'currentRound', coalesce(v_current_round,
                             greatest(coalesce(v_max_round, 1) - 1, 0)),
    'status', v_status,
    'createdAt', v_tournament.opened_at,
    'completedAt', v_tournament.finished_at,
    'rounds', coalesce(v_rounds, '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION public.get_tournament_bracket() OWNER TO postgres;

--
-- Name: is_room_participant(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_room_participant(p_room_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = auth.uid()
  );
$$;


ALTER FUNCTION public.is_room_participant(p_room_id uuid) OWNER TO postgres;

--
-- Name: join_matchmaking(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.join_matchmaking(p_category_name text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_player_id uuid;
  v_opponent uuid;
  v_room_id uuid;
  v_room_code text;
  v_category_id uuid;
  v_opponent_name text;
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt integer;
  v_i integer;
  v_search_category text;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;
  -- Arama kaydı için kullanılacak kategori adı.
  -- Rastgele aramada herkes 'Rastgele' kategorisinde sıraya girer ki eşleşebilsinler.
  v_search_category := coalesce(p_category_name, 'Rastgele');
  if upper(v_search_category) = 'RASTGELE' or upper(v_search_category) = 'RANDOM' then
    -- Rastgele aramada veritabanından rastgele bir kategori seçilir.
    select id into v_category_id
    from public.categories
    order by random()
    limit 1;
  else
    select id into v_category_id
    from public.categories
    where upper(name) = upper(v_search_category)
    limit 1;
  end if;
  if v_category_id is null then
    select id into v_category_id
    from public.categories
    where slug = 'ziman'
    limit 1;
  end if;
  -- Eski kaydını ve 2 dakikadan eski hayalet kayıtları temizle.
  delete from public.matchmaking_queue where player_id = v_player_id;
  delete from public.matchmaking_queue
  where room_id is null
    and joined_at < now() - interval '2 minutes';
  -- Aynı kategoride (yani 'Rastgele' veya belirli kategoride) bekleyen en eski oyuncu.
  select player_id into v_opponent
  from public.matchmaking_queue
  where category_name = v_search_category
    and player_id <> v_player_id
    and room_id is null
  order by joined_at asc
  limit 1
  for update skip locked;
  if v_opponent is not null then
    v_attempt := 0;
    loop
      v_attempt := v_attempt + 1;
      v_room_code := 'ZK-';
      for v_i in 1..4 loop
        v_room_code := v_room_code
          || substr(v_alphabet, 1 + floor(random() * 32)::int, 1);
      end loop;
      begin
        insert into public.rooms (
          code, host_id, category_id, question_count,
          seconds_per_question, status
        )
        values (v_room_code, v_player_id, v_category_id, 10, 15, 'lobby')
        returning id into v_room_id;
        exit;
      exception
        when unique_violation then
          if v_attempt >= 5 then
            raise;
          end if;
      end;
    end loop;
    insert into public.room_players (room_id, player_id, is_ready)
    values
      (v_room_id, v_opponent, true),
      (v_room_id, v_player_id, true);
    -- Bekleyen oyuncunun stream'i bu güncelleme ile odayı öğrenir.
    update public.matchmaking_queue
    set room_id = v_room_id
    where player_id = v_opponent;
    -- Soruları doldurur ve odayı aktif eder.
    perform public.start_room_game(v_room_id);
    select display_name into v_opponent_name
    from public.profiles
    where id = v_opponent;
    return json_build_object(
      'status', 'matched',
      'room_id', v_room_id,
      'code', v_room_code,
      'opponent_name', coalesce(v_opponent_name, 'Hevrik')
    );
  else
    insert into public.matchmaking_queue (player_id, category_name, room_id)
    values (v_player_id, v_search_category, null);
    return json_build_object('status', 'waiting');
  end if;
end;
$$;


ALTER FUNCTION public.join_matchmaking(p_category_name text) OWNER TO postgres;

--
-- Name: join_room_by_code(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.join_room_by_code(p_code text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


ALTER FUNCTION public.join_room_by_code(p_code text) OWNER TO postgres;

--
-- Name: join_tournament(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.join_tournament() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user uuid := auth.uid();
  v_name text;
  v_tournament public.tournaments;
  v_count int;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select coalesce(display_name, 'Lîstikvan') into v_name
    from public.profiles where id = v_user;

  -- Zaten bir turnuvada mı? Katılım tekrarlanabilir olmalı: ekranı yeniden
  -- açmak ikinci bir kayıt oluşturmamalı.
  select t.* into v_tournament
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_user
     and t.status in ('open', 'running')
   order by t.opened_at desc
   limit 1;

  if found then
    return jsonb_build_object('tournament_id', v_tournament.id,
                              'status', v_tournament.status);
  end if;

  -- Açık turnuva yoksa aç.
  select * into v_tournament
    from public.tournaments
   where status = 'open'
   order by opened_at asc
   limit 1
   for update;

  if not found then
    insert into public.tournaments default values
    returning * into v_tournament;
  end if;

  insert into public.tournament_entries (tournament_id, player_id, display_name)
  values (v_tournament.id, v_user, coalesce(v_name, 'Lîstikvan'))
  on conflict do nothing;

  select count(*) into v_count
    from public.tournament_entries
   where tournament_id = v_tournament.id;

  -- Kontenjan dolduğunda turnuva başlar ve ilk tur eşleşmeleri kurulur.
  if v_count >= v_tournament.size then
    perform public.start_tournament(v_tournament.id);
    select * into v_tournament from public.tournaments
     where id = v_tournament.id;
  end if;

  return jsonb_build_object('tournament_id', v_tournament.id,
                            'status', v_tournament.status);
end;
$$;


ALTER FUNCTION public.join_tournament() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    display_name text NOT NULL,
    avatar_color text DEFAULT '#2E9E93'::text NOT NULL,
    coins integer DEFAULT 0 NOT NULL,
    rating integer DEFAULT 1000 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    xp integer DEFAULT 0 NOT NULL,
    avatar_icon text,
    avatar_url text,
    avatar_frame text,
    showcase_title text,
    xp_daily_total integer DEFAULT 0 NOT NULL,
    xp_daily_date date,
    player_tag text,
    CONSTRAINT profiles_coins_check CHECK ((coins >= 0))
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: room_players; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room_players (
    room_id uuid NOT NULL,
    player_id uuid NOT NULL,
    score integer DEFAULT 0 NOT NULL,
    streak integer DEFAULT 0 NOT NULL,
    is_ready boolean DEFAULT false NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.room_players REPLICA IDENTITY FULL;


ALTER TABLE public.room_players OWNER TO postgres;

--
-- Name: leaderboard_entries; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.leaderboard_entries WITH (security_invoker='true') AS
 WITH leaderboard_players AS (
         SELECT profiles.id AS player_id
           FROM public.profiles
        UNION
         SELECT DISTINCT room_players.player_id
           FROM public.room_players
        )
 SELECT (row_number() OVER (ORDER BY COALESCE(p.xp, 0) DESC, lp.player_id))::integer AS rank,
    lp.player_id,
    COALESCE(p.display_name, 'Oyuncu'::text) AS display_name,
    COALESCE(p.xp, 0) AS total_score,
    0 AS best_streak,
    0 AS rooms_played,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
   FROM (leaderboard_players lp
     LEFT JOIN public.profiles p ON ((p.id = lp.player_id)));


ALTER VIEW public.leaderboard_entries OWNER TO postgres;

--
-- Name: leaderboard_visible(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.leaderboard_visible(p_limit integer DEFAULT 10) RETURNS SETOF public.leaderboard_entries
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select le.*
  from public.leaderboard_entries le
  where not exists (
    select 1
    from public.blocked_users b
    where b.blocker_id = auth.uid()
      and b.blocked_id = le.player_id
  )
  order by le.total_score desc
  limit least(greatest(coalesce(p_limit, 10), 1), 100);
$$;


ALTER FUNCTION public.leaderboard_visible(p_limit integer) OWNER TO postgres;

--
-- Name: league_tier_for_rank(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.league_tier_for_rank(p_rank integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case
    when p_rank is null or p_rank <= 0 then 'bronz'
    when p_rank <= 10 then 'zer'
    when p_rank <= 25 then 'ziv'
    else 'bronz'
  end;
$$;


ALTER FUNCTION public.league_tier_for_rank(p_rank integer) OWNER TO postgres;

--
-- Name: league_week_start(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.league_week_start(ts timestamp with time zone DEFAULT now()) RETURNS date
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select (date_trunc('week', ts at time zone 'UTC')::date);
$$;


ALTER FUNCTION public.league_week_start(ts timestamp with time zone) OWNER TO postgres;

--
-- Name: list_friends(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.list_friends() RETURNS TABLE(id uuid, friend_id uuid, friend_name text, friend_avatar_color text, created_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    f.id, f.friend_id, f.friend_name, f.friend_avatar_color, f.created_at
  FROM friends f
  WHERE f.user_id = v_user_id
  ORDER BY f.created_at DESC;
END;
$$;


ALTER FUNCTION public.list_friends() OWNER TO postgres;

--
-- Name: list_pending_friend_requests(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.list_pending_friend_requests() RETURNS TABLE(id uuid, from_user_id uuid, from_user_name text, created_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    fr.id, fr.from_user_id, fr.from_user_name, fr.created_at
  FROM friend_requests fr
  WHERE fr.to_user_id = v_user_id AND fr.status = 'pending'
  ORDER BY fr.created_at DESC;
END;
$$;


ALTER FUNCTION public.list_pending_friend_requests() OWNER TO postgres;

--
-- Name: load_lesson(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.load_lesson(p_lesson_id uuid) RETURNS TABLE(id uuid, slug text, title_ku text, title_tr text, description_ku text, category text, icon_name text)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT l.id, l.slug, l.title_ku, l.title_tr, l.description_ku, l.category, l.icon_name
  FROM lessons l
  WHERE l.id = p_lesson_id;
END;
$$;


ALTER FUNCTION public.load_lesson(p_lesson_id uuid) OWNER TO postgres;

--
-- Name: load_lesson_slides(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.load_lesson_slides(p_lesson_id uuid) RETURNS TABLE(id uuid, lesson_id uuid, order_in_lesson integer, content_ku text, content_tr text, example_ku text, image_url text, audio_url text)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT ls.id, ls.lesson_id, ls.order_in_lesson, ls.content_ku, ls.content_tr,
         ls.example_ku, ls.image_url, ls.audio_url
  FROM lesson_slides ls
  WHERE ls.lesson_id = p_lesson_id
  ORDER BY ls.order_in_lesson ASC;
END;
$$;


ALTER FUNCTION public.load_lesson_slides(p_lesson_id uuid) OWNER TO postgres;

--
-- Name: load_lessons_by_category(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.load_lessons_by_category(p_category text) RETURNS TABLE(id uuid, slug text, title_ku text, title_tr text, description_ku text, icon_name text, "order" integer)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id, l.slug, l.title_ku, l.title_tr, l.description_ku, l.icon_name, l.order_in_category
  FROM lessons l
  WHERE l.category = p_category
  ORDER BY l.order_in_category ASC;
END;
$$;


ALTER FUNCTION public.load_lessons_by_category(p_category text) OWNER TO postgres;

--
-- Name: log_analytics_event(text, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_analytics_event(p_event_name text, p_event_params jsonb DEFAULT NULL::jsonb) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  INSERT INTO analytics_events (user_id, event_name, event_params)
  VALUES (v_user_id, p_event_name, p_event_params);

  RETURN QUERY SELECT TRUE, 'Event logged'::TEXT;
END;
$$;


ALTER FUNCTION public.log_analytics_event(p_event_name text, p_event_params jsonb) OWNER TO postgres;

--
-- Name: mark_lesson_completed(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.mark_lesson_completed(p_lesson_id uuid) RETURNS TABLE(marked boolean, completed_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_now TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_now := now();
  INSERT INTO user_lesson_progress (user_id, lesson_id, completed, completed_at)
  VALUES (v_user_id, p_lesson_id, TRUE, v_now)
  ON CONFLICT (user_id, lesson_id)
  DO UPDATE SET completed = TRUE, completed_at = v_now;

  RETURN QUERY SELECT TRUE, v_now;
END;
$$;


ALTER FUNCTION public.mark_lesson_completed(p_lesson_id uuid) OWNER TO postgres;

--
-- Name: suggested_questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggested_questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    category text NOT NULL,
    prompt text NOT NULL,
    option_a text NOT NULL,
    option_b text NOT NULL,
    option_c text NOT NULL,
    option_d text NOT NULL,
    correct_option text NOT NULL,
    explanation text,
    difficulty integer DEFAULT 3,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    review_note text,
    CONSTRAINT suggested_questions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


ALTER TABLE public.suggested_questions OWNER TO postgres;

--
-- Name: moderate_suggested_question(uuid, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.moderate_suggested_question(p_question_id uuid, p_status text, p_review_note text DEFAULT NULL::text) RETURNS public.suggested_questions
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result_row public.suggested_questions;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'moderation requires service_role';
  END IF;

  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'p_status IN (''approved'', ''rejected'')';
  END IF;

  UPDATE public.suggested_questions
  SET status = p_status,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_note = NULLIF(trim(p_review_note), '')
  WHERE id = p_question_id
  RETURNING * INTO result_row;

  IF result_row.id IS NULL THEN
    RAISE EXCEPTION 'suggested question not found';
  END IF;

  RETURN result_row;
END;
$$;


ALTER FUNCTION public.moderate_suggested_question(p_question_id uuid, p_status text, p_review_note text) OWNER TO postgres;

--
-- Name: profiles_client_write_guard(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.profiles_client_write_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  -- security definer fonksiyonlar (postgres olarak calisir) serbesttir;
  -- yalnizca dogrudan REST/istemci guncellemeleri kisitlanir.
  if current_user in ('authenticated', 'anon') then
    -- XP yalnizca award_xp_delta() RPC'si uzerinden yazilir.
    new.xp := old.xp;
    new.xp_daily_total := old.xp_daily_total;
    new.xp_daily_date := old.xp_daily_date;
    -- Coin bakiyesi ve rating hicbir zaman istemciden yazilmaz.
    new.coins := old.coins;
    new.rating := old.rating;
  end if;
  return new;
end;
$$;


ALTER FUNCTION public.profiles_client_write_guard() OWNER TO postgres;

--
-- Name: protect_paid_profile_cosmetics(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.protect_paid_profile_cosmetics() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_icon_changed boolean;
  v_color_changed boolean;
  v_url_changed boolean;
  v_frame_changed boolean;
  v_title_changed boolean;
begin
  if tg_op = 'INSERT' then
    v_icon_changed := true;
    v_color_changed := true;
    v_url_changed := true;
    v_frame_changed := true;
    v_title_changed := true;
  else
    v_icon_changed := new.avatar_icon is distinct from old.avatar_icon;
    v_color_changed := new.avatar_color is distinct from old.avatar_color;
    v_url_changed := new.avatar_url is distinct from old.avatar_url;
    v_frame_changed := new.avatar_frame is distinct from old.avatar_frame;
    v_title_changed := new.showcase_title is distinct from old.showcase_title;
  end if;

  if v_icon_changed
     and new.avatar_icon is not null
     and not (
       new.avatar_icon = any (array[
         'tembur', 'dengbej', 'ciya', 'roj', 'pirtuk', 'newroz', 'ster',
         'pen', 'cihan', 'mertal', 'tac', 'gul', 'dar', 'cav', 'birusk',
         'kupa'
       ])
     ) then
    raise exception 'Invalid avatar icon';
  end if;

  if v_color_changed
     and new.avatar_color is not null
     and new.avatar_color !~ '^#[0-9A-F]{6}$' then
    raise exception 'Invalid avatar color';
  end if;

  if v_url_changed
     and new.avatar_url is not null
     and new.avatar_url !~ (
       '^https://hupivnxgjtsfafulzspo[.]supabase[.]co/storage/v1/object/public/avatars/'
       || new.id::text
       || '/avatar[.](jpg|png)([?]v=[0-9]+)?$'
     ) then
    raise exception 'Avatar URL must point to the owner storage path';
  end if;

  if v_frame_changed
     and new.avatar_frame is not null
     and not (
       new.avatar_frame = any (array['bronze', 'silver', 'gold', 'mamoste'])
     ) then
    raise exception 'Invalid avatar frame';
  end if;

  if v_title_changed
     and new.showcase_title is not null
     and new.showcase_title <> 'VIP'
     and new.showcase_title !~ '^(Xwendekar|Pispor|Mamoste) · (Ziman|Çand|Dîrok|Edebiyat|Wêje|Cografya|Erdnîgarî|Muzîk|Siyaset|Paradigma|Paradîgma|Sînema|Teknolojî)$' then
    raise exception 'Invalid showcase title';
  end if;

  if new.showcase_title = 'VIP'
     and v_title_changed
     and not exists (
       select 1
       from public.shop_purchases sp
       where sp.player_id = new.id
         and sp.item_id = 'profile_badge_vip'
     ) then
    raise exception 'VIP badge has not been purchased';
  end if;
  return new;
end;
$_$;


ALTER FUNCTION public.protect_paid_profile_cosmetics() OWNER TO postgres;

--
-- Name: reject_friend_request(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reject_friend_request(p_request_id uuid) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_updated INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  UPDATE friend_requests
  SET status = 'rejected'
  WHERE id = p_request_id
    AND to_user_id = v_user_id
    AND status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN QUERY SELECT FALSE, 'Request not found'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT TRUE, 'Request rejected'::TEXT;
END;
$$;


ALTER FUNCTION public.reject_friend_request(p_request_id uuid) OWNER TO postgres;

--
-- Name: report_player_profile(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.report_player_profile(p_reported_id uuid, p_reason text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  -- Kendini bildirmek anlamsız; sessizce başarı dönmek yerine açıkça
  -- reddedilir ki istemci hatayı gösterebilsin.
  if v_uid = p_reported_id then
    return jsonb_build_object('success', false, 'error', 'cannot report self');
  end if;

  if p_reported_id is null
     or not exists (select 1 from public.profiles where id = p_reported_id)
  then
    return jsonb_build_object('success', false, 'error', 'unknown profile');
  end if;

  insert into public.profile_reports (reporter_id, reported_id, reason)
  values (v_uid, p_reported_id, coalesce(nullif(btrim(p_reason), ''), 'unspecified'))
  on conflict (reporter_id, reported_id) do update
    set reason = excluded.reason,
        created_at = now();

  -- Bildiren kişi için engeli de kur: bildirdiği avatarı/adı bir daha
  -- görmek zorunda kalmamalı. Apple 1.2'nin "engelleme" maddesi ile
  -- "bildirme" maddesi kullanıcı gözünde tek bir eylemdir.
  insert into public.blocked_users (blocker_id, blocked_id)
  values (v_uid, p_reported_id)
  on conflict do nothing;

  return jsonb_build_object('success', true);
end;
$$;


ALTER FUNCTION public.report_player_profile(p_reported_id uuid, p_reason text) OWNER TO postgres;

--
-- Name: report_question(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.report_question(p_question_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_count integer;
  v_status text;
begin
  update public.questions
    set report_count = coalesce(report_count, 0) + 1
    where id = p_question_id
    returning report_count, review_status into v_count, v_status;

  if v_count >= 5 and (v_status is distinct from 'rejected') then
    update public.questions
      set review_status = 'needsReview'
      where id = p_question_id;
  end if;
end;
$$;


ALTER FUNCTION public.report_question(p_question_id text) OWNER TO postgres;

--
-- Name: report_room_message(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.report_room_message(p_message_id uuid, p_reason text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  insert into public.message_reports (message_id, reporter_id, reason)
  values (p_message_id, auth.uid(), coalesce(nullif(trim(p_reason), ''), 'other'))
  on conflict (message_id, reporter_id) do nothing;
end;
$$;


ALTER FUNCTION public.report_room_message(p_message_id uuid, p_reason text) OWNER TO postgres;

--
-- Name: resolve_expired_tournament_matches(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.resolve_expired_tournament_matches() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_tournament uuid;
begin
  update public.tournament_matches
     set status = 'completed',
         winner_id = case
           when submitted_one is not null and submitted_two is null
             then player_one
           when submitted_two is not null and submitted_one is null
             then player_two
           else null
         end
   where status <> 'completed'
     and deadline is not null
     and deadline < now();

  -- Süresi dolmuş maçı olan her turnuvayı bir tur ilerlet. Ayrı bir
  -- döngü: `advance_tournament` kendi içinde turun tamamlanıp
  -- tamamlanmadığına bakar, erken çağrı zararsızdır.
  for v_tournament in
    select distinct m.tournament_id
      from public.tournament_matches m
     where m.status = 'completed'
       and m.deadline is not null
       and m.deadline < now()
  loop
    perform public.advance_tournament(v_tournament);
  end loop;
end;
$$;


ALTER FUNCTION public.resolve_expired_tournament_matches() OWNER TO postgres;

--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION public.rls_auto_enable() OWNER TO postgres;

--
-- Name: room_players_client_write_guard(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.room_players_client_write_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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


ALTER FUNCTION public.room_players_client_write_guard() OWNER TO postgres;

--
-- Name: save_tournament_progress(text, integer, integer, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[]) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_today DATE := CURRENT_DATE;
  v_current_stage TEXT;
  v_current_rank INT := 0;
  v_requested_rank INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  IF p_stage NOT IN ('lobby', 'quarter', 'semi', 'final', 'won', 'lost') THEN
    RETURN QUERY SELECT FALSE, 'Invalid tournament stage'::TEXT;
    RETURN;
  END IF;

  SELECT stage
    INTO v_current_stage
    FROM public.tournament_progress
   WHERE user_id = v_user_id
     AND tournament_date = v_today
   FOR UPDATE;

  v_current_rank := CASE v_current_stage
    WHEN 'lobby' THEN 0
    WHEN 'quarter' THEN 1
    WHEN 'semi' THEN 2
    WHEN 'final' THEN 3
    WHEN 'won' THEN 4
    WHEN 'lost' THEN 4
    ELSE 0
  END;

  v_requested_rank := CASE p_stage
    WHEN 'lobby' THEN 0
    WHEN 'quarter' THEN 1
    WHEN 'semi' THEN 2
    WHEN 'final' THEN 3
    WHEN 'won' THEN 4
    WHEN 'lost' THEN 4
    ELSE -1
  END;

  IF p_stage <> 'lost'
     AND v_current_stage IS NOT NULL
     AND v_requested_rank > v_current_rank + 1 THEN
    RETURN QUERY SELECT FALSE, 'Tournament stage jump rejected'::TEXT;
    RETURN;
  END IF;

  IF p_stage = 'won'
     AND (v_current_stage IS NULL OR v_current_stage <> 'final') THEN
    RETURN QUERY SELECT FALSE, 'Tournament champion must complete final'::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.tournament_progress (
    user_id, tournament_date, stage, user_score, opponent_score, bot_winners
  )
  VALUES (v_user_id, v_today, p_stage, p_user_score, p_opponent_score, p_bot_winners)
  ON CONFLICT (user_id, tournament_date) DO UPDATE SET
    stage = EXCLUDED.stage,
    user_score = EXCLUDED.user_score,
    opponent_score = EXCLUDED.opponent_score,
    bot_winners = EXCLUDED.bot_winners,
    updated_at = now();

  RETURN QUERY SELECT TRUE, 'Tournament progress saved'::TEXT;
END;
$$;


ALTER FUNCTION public.save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[]) OWNER TO postgres;

--
-- Name: search_profiles(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_profiles(p_query text) RETURNS TABLE(id uuid, display_name text, avatar_color text, player_tag text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_query text := trim(coalesce(p_query, ''));
  v_tag text := upper(v_query);
  v_pattern text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if length(v_query) < 2 then
    return;
  end if;

  -- Ters bölü ÖNCE kaçırılır, yoksa kendisinden sonra eklenenleri bozar.
  v_pattern := '%' ||
    replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') ||
    '%';

  return query
  select p.id, p.display_name, p.avatar_color, p.player_tag
  from public.profiles p
  where p.id <> v_user_id
    and (p.player_tag = v_tag or p.display_name ilike v_pattern escape '\')
  -- Kod eşleşmesi başa: birebir arayan, aradığını ilk satırda görür.
  order by (p.player_tag = v_tag) desc, p.display_name
  limit 10;
end;
$$;


ALTER FUNCTION public.search_profiles(p_query text) OWNER TO postgres;

--
-- Name: set_room_ready(uuid, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_room_ready(p_room_id uuid, p_is_ready boolean) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


ALTER FUNCTION public.set_room_ready(p_room_id uuid, p_is_ready boolean) OWNER TO postgres;

--
-- Name: spend_coins(integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spend_coins(p_amount integer, p_reason text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_balance integer;
  v_expected integer;
  v_item_id text;
  v_transaction_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  v_expected := case p_reason
    when 'wildcard_fifty_fifty' then 20
    when 'wildcard_audience' then 30
    when 'wildcard_double_answer' then 50
    when 'wildcard_change_question' then 40
    when 'streak_freeze' then 50
    else null
  end;

  if left(p_reason, 9) = 'purchase_' then
    v_item_id := substring(p_reason from 10);
    if not (
      v_item_id = any (array[
        'spin_wheel_extra',
        'avatar_frame_gold',
        'avatar_frame_neon',   -- 2026-08-02: eksikti; ürün alınamıyordu
        'profile_badge_vip'
      ])
    ) then
      return jsonb_build_object(
        'success', false,
        'error', 'product not available'
      );
    end if;
    select cost into v_expected
    from public.shop_items
    where id = v_item_id;
  end if;

  if p_amount <= 0
     or v_expected is null
     or v_expected <= 0
     or p_amount is distinct from v_expected then
    return jsonb_build_object('success', false, 'error', 'invalid price');
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  if v_item_id is not null
     and v_item_id <> 'spin_wheel_extra'
     and exists (
       select 1
       from public.shop_purchases
       where player_id = v_uid
         and item_id = v_item_id
     ) then
    return jsonb_build_object('success', false, 'error', 'already purchased');
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions
  where player_id = v_uid;

  if v_balance < v_expected then
    return jsonb_build_object('success', false, 'balance', v_balance);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_expected, p_reason)
  returning id into v_transaction_id;

  if v_item_id is not null then
    insert into public.shop_purchases (
      player_id,
      item_id,
      price_paid,
      coin_transaction_id
    ) values (
      v_uid,
      v_item_id,
      v_expected,
      v_transaction_id
    );
  end if;
  return jsonb_build_object(
    'success', true,
    'balance', v_balance - v_expected
  );
end;
$$;


ALTER FUNCTION public.spend_coins(p_amount integer, p_reason text) OWNER TO postgres;

--
-- Name: start_due_tournaments(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.start_due_tournaments() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_id uuid;
begin
  for v_id in
    select t.id
      from public.tournaments t
     where t.status = 'open'
       and t.opened_at + make_interval(hours => t.fill_hours) < now()
       and (select count(*) from public.tournament_entries e
             where e.tournament_id = t.id) >= t.min_size
  loop
    perform public.start_tournament(v_id);
  end loop;
end;
$$;


ALTER FUNCTION public.start_due_tournaments() OWNER TO postgres;

--
-- Name: start_room_game(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.start_room_game(p_room_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


ALTER FUNCTION public.start_room_game(p_room_id uuid) OWNER TO postgres;

--
-- Name: start_tournament(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.start_tournament(p_tournament_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_tournament public.tournaments;
  v_players uuid[];
  v_i int;
  v_slot int := 0;
begin
  select * into v_tournament from public.tournaments
   where id = p_tournament_id for update;
  if not found or v_tournament.status <> 'open' then
    return;
  end if;

  -- Katılım sırasına göre eşleştirilir: ilk gelen ilk sıraya. Rastgele
  -- eşleştirme de mümkündü ama katılım sırası hem yeniden üretilebilir
  -- hem de açıklanabilir.
  select array_agg(player_id order by joined_at)
    into v_players
    from public.tournament_entries
   where tournament_id = p_tournament_id;

  v_i := 1;
  while v_i <= array_length(v_players, 1) loop
    insert into public.tournament_matches (
      tournament_id, round, slot, player_one, player_two, deadline
    ) values (
      p_tournament_id, 1, v_slot,
      v_players[v_i],
      v_players[v_i + 1],  -- tek sayıda oyuncuda null: hükmen geçer
      now() + make_interval(hours => v_tournament.round_hours)
    );
    v_slot := v_slot + 1;
    v_i := v_i + 2;
  end loop;

  -- Rakipsiz kalan oyuncu beklemeden ilerler.
  update public.tournament_matches
     set status = 'completed', winner_id = player_one
   where tournament_id = p_tournament_id
     and round = 1
     and player_two is null;

  update public.tournaments
     set status = 'running', started_at = now()
   where id = p_tournament_id;
end;
$$;


ALTER FUNCTION public.start_tournament(p_tournament_id uuid) OWNER TO postgres;

--
-- Name: submit_answer(uuid, uuid, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer DEFAULT 2000) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


ALTER FUNCTION public.submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer) OWNER TO postgres;

--
-- Name: submit_contest_entry(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.submit_contest_entry(p_contest_id uuid, p_correct_count integer) RETURNS TABLE(entry_id uuid, score integer, rank integer, participation_reward integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  raise exception 'contest_verification_required';
end;
$$;


ALTER FUNCTION public.submit_contest_entry(p_contest_id uuid, p_correct_count integer) OWNER TO postgres;

--
-- Name: submit_tournament_match(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.submit_tournament_match(p_match_id uuid, p_score integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user uuid := auth.uid();
  v_match public.tournament_matches;
  v_winner uuid;
  v_score int := greatest(coalesce(p_score, 0), 0);
  v_max_score int;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select * into v_match from public.tournament_matches
   where id = p_match_id for update;
  if not found then
    raise exception 'Match not found';
  end if;
  if v_user not in (coalesce(v_match.player_one, '00000000-0000-0000-0000-000000000000'::uuid),
                    coalesce(v_match.player_two, '00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'Player is not in this match';
  end if;
  if v_match.status = 'completed' then
    return jsonb_build_object('status', 'completed',
                              'winner_id', v_match.winner_id);
  end if;

  -- Skor tavanı: oyunun puanlamasının izin verdiği en yüksek değer.
  -- Soru başına 150 (100 taban + 50 seri bonusu tavanı).
  select coalesce(t.questions_per_match, 4) * 150
    into v_max_score
    from public.tournaments t
   where t.id = v_match.tournament_id;

  v_score := least(v_score, coalesce(v_max_score, 600));

  -- Skor tek sefer kabul edilir: ikinci gönderim sessizce yok sayılır,
  -- yoksa oyuncu turu tekrar oynayıp skorunu yükseltebilirdi.
  if v_user = v_match.player_one and v_match.submitted_one is null then
    update public.tournament_matches
       set score_one = v_score, submitted_one = now()
     where id = p_match_id;
  elsif v_user = v_match.player_two and v_match.submitted_two is null then
    update public.tournament_matches
       set score_two = v_score, submitted_two = now()
     where id = p_match_id;
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;

  if v_match.submitted_one is not null and v_match.submitted_two is not null
  then
    -- Eşitlikte daha erken bitiren geçer: aynı skoru önce tamamlamak
    -- ölçülebilir bir üstünlüktür ve yazı-tura atmaktan yeğdir.
    if coalesce(v_match.score_one, 0) > coalesce(v_match.score_two, 0) then
      v_winner := v_match.player_one;
    elsif coalesce(v_match.score_two, 0) > coalesce(v_match.score_one, 0) then
      v_winner := v_match.player_two;
    elsif v_match.submitted_one <= v_match.submitted_two then
      v_winner := v_match.player_one;
    else
      v_winner := v_match.player_two;
    end if;

    update public.tournament_matches
       set status = 'completed', winner_id = v_winner
     where id = p_match_id;

    perform public.advance_tournament(v_match.tournament_id);
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;
  return jsonb_build_object('status', v_match.status,
                            'winner_id', v_match.winner_id);
end;
$$;


ALTER FUNCTION public.submit_tournament_match(p_match_id uuid, p_score integer) OWNER TO postgres;

--
-- Name: sync_mission_completion(text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_today DATE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  v_today := CURRENT_DATE;

  -- Insert mission completion
  INSERT INTO mission_completions (
    user_id, mission_key, completion_date, coin_reward, xp_reward
  )
  VALUES (v_user_id, p_mission_key, v_today, p_coin_reward, p_xp_reward)
  ON CONFLICT (user_id, mission_key, completion_date) DO NOTHING;

  RETURN QUERY SELECT TRUE, 'Mission completion synced'::TEXT;
END;
$$;


ALTER FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer) OWNER TO postgres;

--
-- Name: unblock_player(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.unblock_player(p_blocked_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from public.blocked_users
   where blocker_id = auth.uid() and blocked_id = p_blocked_id;
end;
$$;


ALTER FUNCTION public.unblock_player(p_blocked_id uuid) OWNER TO postgres;

--
-- Name: zk_display_name_is_clean(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.zk_display_name_is_clean(p_name text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO 'public'
    AS $$
declare
  v_trimmed text := btrim(coalesce(p_name, ''));
  v_norm text;
  v_word text;
  -- `ChatModerationPolicy.blockedWords` ile aynı liste (sadeleştirilmiş).
  v_blocked text[] := array[
    'orospu', 'pic', 'yavsak', 'sikeyim', 'siktir', 'amk',
    'orospucocugu', 'gavat', 'serefsiz', 'ibne', 'pezevenk',
    'yarrak', 'amina', 'sikik', 'gerizekali',
    'qehpik', 'qehbe', 'kerbeso', 'quna', 'beseref'
  ];
  -- `DisplayNamePolicy.reservedWords` ile aynı liste.
  v_reserved text[] := array[
    'zankurd', 'admin', 'administrator', 'yonetici', 'moderator',
    'destek', 'support', 'resmi', 'official', 'sistem', 'system'
  ];
begin
  if v_trimmed = '' then
    return false;
  end if;

  -- Sunucunun KENDİ atadığı varsayılan ad muaftır.
  --
  -- `ensureProfile()` her yeni kullanıcıya 'ZanKurd Oyuncusu' yazıyor ve
  -- bu ad markayı içerdiği için korunan-ad kuralına takılıyordu. Muafiyet
  -- olmasaydı tetikleyici HER YENİ KULLANICININ profil INSERT'ini
  -- reddeder, yani kayıt akışı tamamen kırılırdı.
  --
  -- Depo bu sınıftan bir kazayı zaten yaşadı: `assign_player_tag`
  -- düştüğünde `ensureProfile()` istisnayı yutuyor, uygulama normal
  -- görünüyor ama profil satırı hiç oluşmuyordu (applied.md, 2026-08-01).
  --
  -- Muafiyet TAM eşleşmedir: 'ZanKurd Destek' hâlâ reddedilir.
  if v_trimmed = 'ZanKurd Oyuncusu' then
    return true;
  end if;

  -- Görünen karakter sayısı (çok baytlı harfler tek sayılır).
  if char_length(v_trimmed) < 2 or char_length(v_trimmed) > 24 then
    return false;
  end if;

  -- Kontrol ve görünmez karakterler: yön değiştiriciler (U+202A..U+202E)
  -- kimlik taklidine ve liderlik tablosunda hizalama kırmaya yarar.
  -- Kontrol ve görünmez karakterler.
  --
  -- E'' kaçış dizileriyle yazılır: ilk yazımda karakterler HAM olarak
  -- gömülmüştü ve Management API çağrısı `08P01 invalid message format`
  -- ile düşüyordu — U+0000..U+001F aralığı tel protokolünde taşınamaz.
  -- U+0000 zaten kapsam dışı: Postgres `text` NUL taşıyamaz.
  --
  -- U+202A..U+202E (yön değiştiriciler) önemlidir: liderlik tablosunda
  -- hizalamayı kırar ve tersten okunarak kimlik taklidine yarar.
  if v_trimmed ~ E'[\u0001-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]' then
    return false;
  end if;

  -- Bağlantı: reklam ve oltalama yüzeyi.
  -- TLD listesi Dart tarafındaki `DisplayNamePolicy._link` ile AYNI
  -- olmalı. İlk yazımda kısaltma alan adları (ly, gl, co…) eksikti ve
  -- 'bit.ly/x' sunucuda KABUL ediliyordu — istemci reddederken sunucu
  -- geçiriyordu, yani asıl kapı açıktı. 24 karaktere ancak kısa
  -- bağlantılar sığar, spam vektörü tam olarak onlardır.
  if lower(v_trimmed) ~ '(https?://|www\.|[a-z0-9-]+\.(com|net|org|io|me|tk|ru|xyz|link|ly|gl|co|cc|to|im|app|site|info|biz))' then
    return false;
  end if;

  v_norm := public.zk_normalize_text(v_trimmed);

  -- TAM SÖZCÜK eşleşmesi. Alt dizi araması masum adları yakalardı
  -- ("Pinar" içinde "pi", Kurmancîde "got" = "söz").
  foreach v_word in array regexp_split_to_array(v_norm, '[^a-z]+')
  loop
    if v_word = '' then
      continue;
    end if;
    if v_word = any (v_blocked) then
      return false;
    end if;
    if v_word = any (v_reserved) then
      return false;
    end if;
  end loop;

  return true;
end;
$$;


ALTER FUNCTION public.zk_display_name_is_clean(p_name text) OWNER TO postgres;

--
-- Name: zk_normalize_text(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.zk_normalize_text(p_input text) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $_$
  -- from/to UZUNLUKLARI eşit olmalı: Postgres `translate`ta `from`un
  -- fazlası SESSİZCE SİLİNİR. İlk yazımda uzunluklar tutmuyordu ve
  -- '@' -> 's', '$' -> 'a' gibi yanlış eşleşmeler oluşuyordu.
  -- Dart tarafındaki `ChatModerationPolicy._normalize` ile birebir aynı
  -- (girdi zaten lower()'landığı için büyük harf varyantları gerekmez).
  select translate(
    lower(coalesce(p_input, '')),
    'ışğüöçîêû01345@$',
    'isguocieuoieasas'
  );
$_$;


ALTER FUNCTION public.zk_normalize_text(p_input text) OWNER TO postgres;

--
-- Name: analytics_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.analytics_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    event_name text NOT NULL,
    event_params jsonb,
    event_timestamp timestamp with time zone DEFAULT now()
);


ALTER TABLE public.analytics_events OWNER TO postgres;

--
-- Name: blocked_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocked_users (
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT blocked_users_no_self CHECK ((blocker_id <> blocked_id))
);


ALTER TABLE public.blocked_users OWNER TO postgres;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: coin_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coin_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    player_id uuid NOT NULL,
    amount integer NOT NULL,
    reason text NOT NULL,
    play_purchase_token text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.coin_transactions OWNER TO postgres;

--
-- Name: contest_badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contest_badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    name_ku text NOT NULL,
    description_ku text,
    icon_name text,
    color_hex text,
    tier integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.contest_badges OWNER TO postgres;

--
-- Name: contest_entries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contest_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contest_id uuid NOT NULL,
    user_id uuid NOT NULL,
    score integer DEFAULT 0,
    correct_count integer DEFAULT 0,
    finished_at timestamp with time zone,
    rank integer,
    reward_claimed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.contest_entries OWNER TO postgres;

--
-- Name: contests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    day_key date NOT NULL,
    theme_name_ku text NOT NULL,
    theme_description_ku text,
    category text NOT NULL,
    difficulty_min integer DEFAULT 1,
    difficulty_max integer DEFAULT 5,
    participation_reward integer DEFAULT 10,
    rank1_reward integer DEFAULT 500,
    rank2_reward integer DEFAULT 300,
    rank3_reward integer DEFAULT 100,
    question_count integer DEFAULT 10,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.contests OWNER TO postgres;

--
-- Name: favorite_questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.favorite_questions (
    player_id uuid NOT NULL,
    question_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.favorite_questions OWNER TO postgres;

--
-- Name: friend_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.friend_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    from_user_id uuid NOT NULL,
    from_user_name text NOT NULL,
    to_user_id uuid NOT NULL,
    status text DEFAULT 'pending'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT friend_requests_check CHECK ((from_user_id <> to_user_id))
);


ALTER TABLE public.friend_requests OWNER TO postgres;

--
-- Name: friends; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.friends (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    friend_id uuid NOT NULL,
    friend_name text NOT NULL,
    friend_avatar_color text DEFAULT '#E94560'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT friends_check CHECK ((user_id <> friend_id))
);


ALTER TABLE public.friends OWNER TO postgres;

--
-- Name: league_memberships; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.league_memberships (
    week_start date NOT NULL,
    player_id uuid NOT NULL,
    tier text NOT NULL,
    weekly_score bigint DEFAULT 0 NOT NULL,
    weekly_rank integer,
    previous_tier text,
    promoted boolean DEFAULT false NOT NULL,
    relegated boolean DEFAULT false NOT NULL,
    CONSTRAINT league_memberships_previous_tier_check CHECK (((previous_tier IS NULL) OR (previous_tier = ANY (ARRAY['bronz'::text, 'ziv'::text, 'zer'::text])))),
    CONSTRAINT league_memberships_tier_check CHECK ((tier = ANY (ARRAY['bronz'::text, 'ziv'::text, 'zer'::text])))
);


ALTER TABLE public.league_memberships OWNER TO postgres;

--
-- Name: league_weeks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.league_weeks (
    week_start date NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    finalized_at timestamp with time zone,
    notes text,
    CONSTRAINT league_weeks_status_check CHECK ((status = ANY (ARRAY['open'::text, 'finalizing'::text, 'closed'::text])))
);


ALTER TABLE public.league_weeks OWNER TO postgres;

--
-- Name: lesson_slides; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lesson_slides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lesson_id uuid NOT NULL,
    order_in_lesson integer NOT NULL,
    content_ku text NOT NULL,
    content_tr text,
    example_ku text,
    image_url text,
    audio_url text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.lesson_slides OWNER TO postgres;

--
-- Name: lessons; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lessons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title_ku text NOT NULL,
    title_tr text,
    description_ku text,
    category text NOT NULL,
    icon_name text,
    order_in_category integer DEFAULT 0,
    language text DEFAULT 'ku'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.lessons OWNER TO postgres;

--
-- Name: matchmaking_queue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matchmaking_queue (
    player_id uuid NOT NULL,
    category_name text NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    room_id uuid
);


ALTER TABLE public.matchmaking_queue OWNER TO postgres;

--
-- Name: message_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.message_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    message_id uuid NOT NULL,
    reporter_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.message_reports OWNER TO postgres;

--
-- Name: mission_completions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mission_completions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    mission_key text NOT NULL,
    completion_date date NOT NULL,
    coin_reward integer NOT NULL,
    xp_reward integer NOT NULL,
    claimed boolean DEFAULT false,
    completed_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.mission_completions OWNER TO postgres;

--
-- Name: player_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_answers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    question_id uuid NOT NULL,
    player_id uuid NOT NULL,
    selected_option text NOT NULL,
    is_correct boolean DEFAULT false NOT NULL,
    response_ms integer NOT NULL,
    points_awarded integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT player_answers_response_ms_check CHECK ((response_ms >= 0)),
    CONSTRAINT player_answers_selected_option_check CHECK ((selected_option = ANY (ARRAY['A'::text, 'B'::text, 'C'::text, 'D'::text, 'TIMEOUT'::text])))
);


ALTER TABLE public.player_answers OWNER TO postgres;

--
-- Name: profile_cosmetic_quarantine; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profile_cosmetic_quarantine (
    profile_id uuid NOT NULL,
    avatar_url text,
    avatar_frame text,
    showcase_title text,
    quarantined_at timestamp with time zone DEFAULT now() NOT NULL,
    reason text NOT NULL
);


ALTER TABLE public.profile_cosmetic_quarantine OWNER TO postgres;

--
-- Name: profile_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profile_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    reported_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.profile_reports OWNER TO postgres;

--
-- Name: question_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.question_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question_id uuid NOT NULL,
    reporter_id uuid,
    reason text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.question_reports OWNER TO postgres;

--
-- Name: questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    language_code text DEFAULT 'ku-kmr'::text NOT NULL,
    prompt text NOT NULL,
    option_a text NOT NULL,
    option_b text NOT NULL,
    option_c text NOT NULL,
    option_d text NOT NULL,
    correct_option text NOT NULL,
    explanation text,
    source_url text,
    difficulty integer DEFAULT 2 NOT NULL,
    is_approved boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    question_type text DEFAULT 'multiple_choice'::text NOT NULL,
    image_url text,
    explanation_ku text,
    explanation_tr text,
    review_status text,
    dialect text,
    source_title text,
    source_reference text,
    reviewed_by text,
    reviewed_at timestamp with time zone,
    last_content_check_at timestamp with time zone,
    quality_version integer DEFAULT 0 NOT NULL,
    report_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT questions_correct_option_check CHECK ((correct_option = ANY (ARRAY['A'::text, 'B'::text, 'C'::text, 'D'::text]))),
    CONSTRAINT questions_difficulty_check CHECK (((difficulty >= 1) AND (difficulty <= 5))),
    CONSTRAINT questions_question_type_check CHECK ((question_type = ANY (ARRAY['multiple_choice'::text, 'true_false'::text, 'visual'::text]))),
    CONSTRAINT questions_review_status_check CHECK ((review_status = ANY (ARRAY['draft'::text, 'needsReview'::text, 'approved'::text, 'rejected'::text])))
);


ALTER TABLE public.questions OWNER TO postgres;

--
-- Name: quiz_eligible_questions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.quiz_eligible_questions AS
 SELECT id,
    category_id,
    language_code,
    prompt,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_option,
    explanation,
    source_url,
    difficulty,
    is_approved,
    created_by,
    created_at,
    updated_at,
    question_type,
    image_url,
    explanation_ku,
    explanation_tr,
    review_status,
    dialect,
    source_title,
    source_reference,
    reviewed_by,
    reviewed_at,
    last_content_check_at,
    quality_version,
    report_count
   FROM public.questions
  WHERE ((is_approved = true) AND (review_status IS DISTINCT FROM 'rejected'::text));


ALTER VIEW public.quiz_eligible_questions OWNER TO postgres;

--
-- Name: quiz_public_questions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.quiz_public_questions WITH (security_invoker='true') AS
 SELECT id,
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
   FROM public.questions
  WHERE ((is_approved = true) AND (review_status IS DISTINCT FROM 'rejected'::text));


ALTER VIEW public.quiz_public_questions OWNER TO postgres;

--
-- Name: room_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    sender_name text,
    sender_avatar_color text,
    text text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.room_messages OWNER TO postgres;

--
-- Name: room_questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room_questions (
    room_id uuid NOT NULL,
    question_id uuid NOT NULL,
    question_index integer NOT NULL,
    started_at timestamp with time zone,
    revealed_at timestamp with time zone
);


ALTER TABLE public.room_questions OWNER TO postgres;

--
-- Name: rooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    host_id uuid NOT NULL,
    status public.room_status DEFAULT 'lobby'::public.room_status NOT NULL,
    mode public.match_mode DEFAULT 'private_room'::public.match_mode NOT NULL,
    category_id uuid,
    question_count integer DEFAULT 10 NOT NULL,
    seconds_per_question integer DEFAULT 30 NOT NULL,
    current_question_index integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rooms_question_count_check CHECK (((question_count >= 3) AND (question_count <= 30))),
    CONSTRAINT rooms_seconds_per_question_check CHECK (((seconds_per_question >= 5) AND (seconds_per_question <= 60)))
);

ALTER TABLE ONLY public.rooms REPLICA IDENTITY FULL;


ALTER TABLE public.rooms OWNER TO postgres;

--
-- Name: shop_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shop_items (
    id text NOT NULL,
    title_ku text NOT NULL,
    title_tr text NOT NULL,
    desc_ku text NOT NULL,
    desc_tr text NOT NULL,
    cost integer NOT NULL,
    icon_name text,
    theme_color text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shop_items OWNER TO postgres;

--
-- Name: shop_purchases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shop_purchases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    player_id uuid NOT NULL,
    item_id text NOT NULL,
    price_paid integer NOT NULL,
    coin_transaction_id uuid NOT NULL,
    purchased_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT shop_purchases_price_paid_check CHECK ((price_paid > 0))
);


ALTER TABLE public.shop_purchases OWNER TO postgres;

--
-- Name: spin_wheel_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.spin_wheel_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    spin_date date NOT NULL,
    reward_amount integer NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.spin_wheel_history OWNER TO postgres;

--
-- Name: tournament_entries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tournament_entries (
    tournament_id uuid NOT NULL,
    player_id uuid NOT NULL,
    display_name text NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.tournament_entries OWNER TO postgres;

--
-- Name: tournament_matches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tournament_matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tournament_id uuid NOT NULL,
    round integer NOT NULL,
    slot integer NOT NULL,
    player_one uuid,
    player_two uuid,
    score_one integer,
    score_two integer,
    submitted_one timestamp with time zone,
    submitted_two timestamp with time zone,
    winner_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    deadline timestamp with time zone
);


ALTER TABLE public.tournament_matches OWNER TO postgres;

--
-- Name: tournament_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tournament_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    tournament_date date NOT NULL,
    stage text,
    user_score integer DEFAULT 0,
    opponent_score integer DEFAULT 0,
    bot_winners text[],
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.tournament_progress OWNER TO postgres;

--
-- Name: tournaments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tournaments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    size integer DEFAULT 4 NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    round_hours integer DEFAULT 24 NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    champion_id uuid,
    min_size integer DEFAULT 2 NOT NULL,
    fill_hours integer DEFAULT 24 NOT NULL,
    questions_per_match integer DEFAULT 4 NOT NULL
);


ALTER TABLE public.tournaments OWNER TO postgres;

--
-- Name: COLUMN tournaments.questions_per_match; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.tournaments.questions_per_match IS 'Bir maçtaki soru sayısı. submit_tournament_match skor tavanını buradan türetir: questions_per_match * 150 (soru başına en yüksek puan).';


--
-- Name: user_contest_badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_contest_badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    badge_id uuid NOT NULL,
    contest_id uuid NOT NULL,
    earned_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.user_contest_badges OWNER TO postgres;

--
-- Name: user_lesson_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_lesson_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    lesson_id uuid NOT NULL,
    completed boolean DEFAULT false,
    last_viewed_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.user_lesson_progress OWNER TO postgres;

--
-- Name: analytics_events analytics_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (id);


--
-- Name: blocked_users blocked_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_pkey PRIMARY KEY (blocker_id, blocked_id);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: coin_transactions coin_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coin_transactions
    ADD CONSTRAINT coin_transactions_pkey PRIMARY KEY (id);


--
-- Name: contest_badges contest_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_badges
    ADD CONSTRAINT contest_badges_pkey PRIMARY KEY (id);


--
-- Name: contest_badges contest_badges_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_badges
    ADD CONSTRAINT contest_badges_slug_key UNIQUE (slug);


--
-- Name: contest_entries contest_entries_contest_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_entries
    ADD CONSTRAINT contest_entries_contest_id_user_id_key UNIQUE (contest_id, user_id);


--
-- Name: contest_entries contest_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_entries
    ADD CONSTRAINT contest_entries_pkey PRIMARY KEY (id);


--
-- Name: contests contests_day_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contests
    ADD CONSTRAINT contests_day_key_key UNIQUE (day_key);


--
-- Name: contests contests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contests
    ADD CONSTRAINT contests_pkey PRIMARY KEY (id);


--
-- Name: favorite_questions favorite_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorite_questions
    ADD CONSTRAINT favorite_questions_pkey PRIMARY KEY (player_id, question_id);


--
-- Name: friend_requests friend_requests_from_user_id_to_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_from_user_id_to_user_id_key UNIQUE (from_user_id, to_user_id);


--
-- Name: friend_requests friend_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_pkey PRIMARY KEY (id);


--
-- Name: friends friends_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friends
    ADD CONSTRAINT friends_pkey PRIMARY KEY (id);


--
-- Name: friends friends_user_id_friend_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friends
    ADD CONSTRAINT friends_user_id_friend_id_key UNIQUE (user_id, friend_id);


--
-- Name: league_memberships league_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_memberships
    ADD CONSTRAINT league_memberships_pkey PRIMARY KEY (week_start, player_id);


--
-- Name: league_weeks league_weeks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_weeks
    ADD CONSTRAINT league_weeks_pkey PRIMARY KEY (week_start);


--
-- Name: lesson_slides lesson_slides_lesson_id_order_in_lesson_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lesson_slides
    ADD CONSTRAINT lesson_slides_lesson_id_order_in_lesson_key UNIQUE (lesson_id, order_in_lesson);


--
-- Name: lesson_slides lesson_slides_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lesson_slides
    ADD CONSTRAINT lesson_slides_pkey PRIMARY KEY (id);


--
-- Name: lessons lessons_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_pkey PRIMARY KEY (id);


--
-- Name: lessons lessons_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_slug_key UNIQUE (slug);


--
-- Name: matchmaking_queue matchmaking_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matchmaking_queue
    ADD CONSTRAINT matchmaking_queue_pkey PRIMARY KEY (player_id);


--
-- Name: message_reports message_reports_message_id_reporter_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message_reports
    ADD CONSTRAINT message_reports_message_id_reporter_id_key UNIQUE (message_id, reporter_id);


--
-- Name: message_reports message_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message_reports
    ADD CONSTRAINT message_reports_pkey PRIMARY KEY (id);


--
-- Name: mission_completions mission_completions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mission_completions
    ADD CONSTRAINT mission_completions_pkey PRIMARY KEY (id);


--
-- Name: mission_completions mission_completions_user_id_mission_key_completion_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mission_completions
    ADD CONSTRAINT mission_completions_user_id_mission_key_completion_date_key UNIQUE (user_id, mission_key, completion_date);


--
-- Name: player_answers player_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_answers
    ADD CONSTRAINT player_answers_pkey PRIMARY KEY (id);


--
-- Name: player_answers player_answers_room_id_question_id_player_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_answers
    ADD CONSTRAINT player_answers_room_id_question_id_player_id_key UNIQUE (room_id, question_id, player_id);


--
-- Name: profile_cosmetic_quarantine profile_cosmetic_quarantine_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_cosmetic_quarantine
    ADD CONSTRAINT profile_cosmetic_quarantine_pkey PRIMARY KEY (profile_id);


--
-- Name: profile_reports profile_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_reports
    ADD CONSTRAINT profile_reports_pkey PRIMARY KEY (id);


--
-- Name: profile_reports profile_reports_reporter_id_reported_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_reports
    ADD CONSTRAINT profile_reports_reporter_id_reported_id_key UNIQUE (reporter_id, reported_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: question_reports question_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.question_reports
    ADD CONSTRAINT question_reports_pkey PRIMARY KEY (id);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: room_messages room_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_messages
    ADD CONSTRAINT room_messages_pkey PRIMARY KEY (id);


--
-- Name: room_players room_players_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_players
    ADD CONSTRAINT room_players_pkey PRIMARY KEY (room_id, player_id);


--
-- Name: room_questions room_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_questions
    ADD CONSTRAINT room_questions_pkey PRIMARY KEY (room_id, question_index);


--
-- Name: room_questions room_questions_room_id_question_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_questions
    ADD CONSTRAINT room_questions_room_id_question_id_key UNIQUE (room_id, question_id);


--
-- Name: rooms rooms_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_code_key UNIQUE (code);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: shop_items shop_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_items
    ADD CONSTRAINT shop_items_pkey PRIMARY KEY (id);


--
-- Name: shop_purchases shop_purchases_coin_transaction_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_purchases
    ADD CONSTRAINT shop_purchases_coin_transaction_id_key UNIQUE (coin_transaction_id);


--
-- Name: shop_purchases shop_purchases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_purchases
    ADD CONSTRAINT shop_purchases_pkey PRIMARY KEY (id);


--
-- Name: spin_wheel_history spin_wheel_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spin_wheel_history
    ADD CONSTRAINT spin_wheel_history_pkey PRIMARY KEY (id);


--
-- Name: spin_wheel_history spin_wheel_history_user_id_spin_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spin_wheel_history
    ADD CONSTRAINT spin_wheel_history_user_id_spin_date_key UNIQUE (user_id, spin_date);


--
-- Name: suggested_questions suggested_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_questions
    ADD CONSTRAINT suggested_questions_pkey PRIMARY KEY (id);


--
-- Name: tournament_entries tournament_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_entries
    ADD CONSTRAINT tournament_entries_pkey PRIMARY KEY (tournament_id, player_id);


--
-- Name: tournament_matches tournament_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_matches
    ADD CONSTRAINT tournament_matches_pkey PRIMARY KEY (id);


--
-- Name: tournament_matches tournament_matches_tournament_id_round_slot_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_matches
    ADD CONSTRAINT tournament_matches_tournament_id_round_slot_key UNIQUE (tournament_id, round, slot);


--
-- Name: tournament_progress tournament_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_progress
    ADD CONSTRAINT tournament_progress_pkey PRIMARY KEY (id);


--
-- Name: tournament_progress tournament_progress_user_id_tournament_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_progress
    ADD CONSTRAINT tournament_progress_user_id_tournament_date_key UNIQUE (user_id, tournament_date);


--
-- Name: tournaments tournaments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournaments
    ADD CONSTRAINT tournaments_pkey PRIMARY KEY (id);


--
-- Name: user_contest_badges user_contest_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_contest_badges
    ADD CONSTRAINT user_contest_badges_pkey PRIMARY KEY (id);


--
-- Name: user_contest_badges user_contest_badges_user_id_badge_id_contest_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_contest_badges
    ADD CONSTRAINT user_contest_badges_user_id_badge_id_contest_id_key UNIQUE (user_id, badge_id, contest_id);


--
-- Name: user_lesson_progress user_lesson_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_lesson_progress
    ADD CONSTRAINT user_lesson_progress_pkey PRIMARY KEY (id);


--
-- Name: user_lesson_progress user_lesson_progress_user_id_lesson_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_lesson_progress
    ADD CONSTRAINT user_lesson_progress_user_id_lesson_id_key UNIQUE (user_id, lesson_id);


--
-- Name: idx_analytics_events_user_timestamp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_analytics_events_user_timestamp ON public.analytics_events USING btree (user_id, event_timestamp DESC);


--
-- Name: idx_contest_entries_contest_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contest_entries_contest_id ON public.contest_entries USING btree (contest_id);


--
-- Name: idx_contest_entries_finished; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contest_entries_finished ON public.contest_entries USING btree (finished_at) WHERE (finished_at IS NOT NULL);


--
-- Name: idx_contest_entries_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contest_entries_user_id ON public.contest_entries USING btree (user_id);


--
-- Name: idx_contests_day_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contests_day_key ON public.contests USING btree (day_key);


--
-- Name: idx_friend_requests_to_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_friend_requests_to_user_id ON public.friend_requests USING btree (to_user_id, status);


--
-- Name: idx_friends_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_friends_user_id ON public.friends USING btree (user_id);


--
-- Name: idx_lesson_slides_lesson_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lesson_slides_lesson_id ON public.lesson_slides USING btree (lesson_id);


--
-- Name: idx_lessons_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lessons_category ON public.lessons USING btree (category);


--
-- Name: idx_lessons_slug; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lessons_slug ON public.lessons USING btree (slug);


--
-- Name: idx_mission_completions_user_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mission_completions_user_date ON public.mission_completions USING btree (user_id, completion_date DESC);


--
-- Name: idx_room_messages_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_room_messages_created_at ON public.room_messages USING btree (created_at);


--
-- Name: idx_room_messages_room_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_room_messages_room_id ON public.room_messages USING btree (room_id);


--
-- Name: idx_spin_wheel_user_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_spin_wheel_user_date ON public.spin_wheel_history USING btree (user_id, spin_date DESC);


--
-- Name: idx_suggested_questions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggested_questions_status ON public.suggested_questions USING btree (status);


--
-- Name: idx_suggested_questions_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_suggested_questions_user_id ON public.suggested_questions USING btree (user_id);


--
-- Name: idx_tournament_progress_user_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tournament_progress_user_date ON public.tournament_progress USING btree (user_id, tournament_date DESC);


--
-- Name: idx_user_contest_badges_badge_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_contest_badges_badge_id ON public.user_contest_badges USING btree (badge_id);


--
-- Name: idx_user_contest_badges_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_contest_badges_user_id ON public.user_contest_badges USING btree (user_id);


--
-- Name: idx_user_lesson_progress_completed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_lesson_progress_completed ON public.user_lesson_progress USING btree (completed) WHERE (completed = true);


--
-- Name: idx_user_lesson_progress_lesson_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_lesson_progress_lesson_id ON public.user_lesson_progress USING btree (lesson_id);


--
-- Name: idx_user_lesson_progress_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_lesson_progress_user_id ON public.user_lesson_progress USING btree (user_id);


--
-- Name: league_memberships_player_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX league_memberships_player_idx ON public.league_memberships USING btree (player_id, week_start DESC);


--
-- Name: league_memberships_week_rank_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX league_memberships_week_rank_idx ON public.league_memberships USING btree (week_start, weekly_rank);


--
-- Name: message_reports_message_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX message_reports_message_idx ON public.message_reports USING btree (message_id);


--
-- Name: profile_reports_reported_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX profile_reports_reported_idx ON public.profile_reports USING btree (reported_id, created_at DESC);


--
-- Name: profiles_player_tag_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX profiles_player_tag_key ON public.profiles USING btree (player_tag);


--
-- Name: shop_purchases_nonrepeatable_uidx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX shop_purchases_nonrepeatable_uidx ON public.shop_purchases USING btree (player_id, item_id) WHERE (item_id <> 'spin_wheel_extra'::text);


--
-- Name: shop_purchases_player_item_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX shop_purchases_player_item_idx ON public.shop_purchases USING btree (player_id, item_id, purchased_at);


--
-- Name: tournament_matches_player_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tournament_matches_player_idx ON public.tournament_matches USING btree (tournament_id, player_one, player_two);


--
-- Name: player_answers player_answers_current_question_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER player_answers_current_question_trg BEFORE INSERT ON public.player_answers FOR EACH ROW EXECUTE FUNCTION public.enforce_current_room_question();


--
-- Name: profiles profiles_assign_player_tag; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER profiles_assign_player_tag BEFORE INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.assign_player_tag();


--
-- Name: profiles profiles_client_write_guard_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER profiles_client_write_guard_trg BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_client_write_guard();


--
-- Name: profiles profiles_freeze_player_tag; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER profiles_freeze_player_tag BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.freeze_player_tag();


--
-- Name: profiles profiles_paid_cosmetics_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER profiles_paid_cosmetics_trg BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.protect_paid_profile_cosmetics();


--
-- Name: room_messages room_messages_moderation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER room_messages_moderation BEFORE INSERT ON public.room_messages FOR EACH ROW EXECUTE FUNCTION public.enforce_chat_moderation();


--
-- Name: room_players room_players_client_write_guard_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER room_players_client_write_guard_trg BEFORE UPDATE ON public.room_players FOR EACH ROW EXECUTE FUNCTION public.room_players_client_write_guard();


--
-- Name: profiles trg_enforce_display_name_policy; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_enforce_display_name_policy BEFORE INSERT OR UPDATE OF display_name ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.enforce_display_name_policy();


--
-- Name: analytics_events analytics_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: blocked_users blocked_users_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: blocked_users blocked_users_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: coin_transactions coin_transactions_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coin_transactions
    ADD CONSTRAINT coin_transactions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: contest_entries contest_entries_contest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_entries
    ADD CONSTRAINT contest_entries_contest_id_fkey FOREIGN KEY (contest_id) REFERENCES public.contests(id) ON DELETE CASCADE;


--
-- Name: contest_entries contest_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_entries
    ADD CONSTRAINT contest_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: favorite_questions favorite_questions_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorite_questions
    ADD CONSTRAINT favorite_questions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: favorite_questions favorite_questions_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorite_questions
    ADD CONSTRAINT favorite_questions_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- Name: friend_requests friend_requests_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: friend_requests friend_requests_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: friends friends_friend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friends
    ADD CONSTRAINT friends_friend_id_fkey FOREIGN KEY (friend_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: friends friends_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.friends
    ADD CONSTRAINT friends_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: league_memberships league_memberships_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_memberships
    ADD CONSTRAINT league_memberships_player_id_fkey FOREIGN KEY (player_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: league_memberships league_memberships_week_start_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_memberships
    ADD CONSTRAINT league_memberships_week_start_fkey FOREIGN KEY (week_start) REFERENCES public.league_weeks(week_start) ON DELETE CASCADE;


--
-- Name: lesson_slides lesson_slides_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lesson_slides
    ADD CONSTRAINT lesson_slides_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;


--
-- Name: matchmaking_queue matchmaking_queue_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matchmaking_queue
    ADD CONSTRAINT matchmaking_queue_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: matchmaking_queue matchmaking_queue_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matchmaking_queue
    ADD CONSTRAINT matchmaking_queue_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- Name: message_reports message_reports_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message_reports
    ADD CONSTRAINT message_reports_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.room_messages(id) ON DELETE CASCADE;


--
-- Name: message_reports message_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message_reports
    ADD CONSTRAINT message_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mission_completions mission_completions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mission_completions
    ADD CONSTRAINT mission_completions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: player_answers player_answers_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_answers
    ADD CONSTRAINT player_answers_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: player_answers player_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_answers
    ADD CONSTRAINT player_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id);


--
-- Name: player_answers player_answers_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_answers
    ADD CONSTRAINT player_answers_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: profile_cosmetic_quarantine profile_cosmetic_quarantine_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_cosmetic_quarantine
    ADD CONSTRAINT profile_cosmetic_quarantine_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: profile_reports profile_reports_reported_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_reports
    ADD CONSTRAINT profile_reports_reported_id_fkey FOREIGN KEY (reported_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profile_reports profile_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_reports
    ADD CONSTRAINT profile_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: question_reports question_reports_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.question_reports
    ADD CONSTRAINT question_reports_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- Name: question_reports question_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.question_reports
    ADD CONSTRAINT question_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: questions questions_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: questions questions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: room_messages room_messages_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_messages
    ADD CONSTRAINT room_messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: room_messages room_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_messages
    ADD CONSTRAINT room_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: room_players room_players_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_players
    ADD CONSTRAINT room_players_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: room_players room_players_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_players
    ADD CONSTRAINT room_players_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: room_questions room_questions_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_questions
    ADD CONSTRAINT room_questions_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id);


--
-- Name: room_questions room_questions_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_questions
    ADD CONSTRAINT room_questions_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: rooms rooms_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: rooms rooms_host_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_host_id_fkey FOREIGN KEY (host_id) REFERENCES public.profiles(id);


--
-- Name: shop_purchases shop_purchases_coin_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_purchases
    ADD CONSTRAINT shop_purchases_coin_transaction_id_fkey FOREIGN KEY (coin_transaction_id) REFERENCES public.coin_transactions(id) ON DELETE CASCADE;


--
-- Name: shop_purchases shop_purchases_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_purchases
    ADD CONSTRAINT shop_purchases_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.shop_items(id) ON DELETE RESTRICT;


--
-- Name: shop_purchases shop_purchases_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shop_purchases
    ADD CONSTRAINT shop_purchases_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: spin_wheel_history spin_wheel_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.spin_wheel_history
    ADD CONSTRAINT spin_wheel_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: suggested_questions suggested_questions_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_questions
    ADD CONSTRAINT suggested_questions_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id);


--
-- Name: suggested_questions suggested_questions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_questions
    ADD CONSTRAINT suggested_questions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: tournament_entries tournament_entries_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_entries
    ADD CONSTRAINT tournament_entries_player_id_fkey FOREIGN KEY (player_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: tournament_entries tournament_entries_tournament_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_entries
    ADD CONSTRAINT tournament_entries_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE;


--
-- Name: tournament_matches tournament_matches_player_one_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_matches
    ADD CONSTRAINT tournament_matches_player_one_fkey FOREIGN KEY (player_one) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: tournament_matches tournament_matches_player_two_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_matches
    ADD CONSTRAINT tournament_matches_player_two_fkey FOREIGN KEY (player_two) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: tournament_matches tournament_matches_tournament_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_matches
    ADD CONSTRAINT tournament_matches_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE;


--
-- Name: tournament_matches tournament_matches_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_matches
    ADD CONSTRAINT tournament_matches_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: tournament_progress tournament_progress_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournament_progress
    ADD CONSTRAINT tournament_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: tournaments tournaments_champion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournaments
    ADD CONSTRAINT tournaments_champion_id_fkey FOREIGN KEY (champion_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: user_contest_badges user_contest_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_contest_badges
    ADD CONSTRAINT user_contest_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.contest_badges(id) ON DELETE CASCADE;


--
-- Name: user_contest_badges user_contest_badges_contest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_contest_badges
    ADD CONSTRAINT user_contest_badges_contest_id_fkey FOREIGN KEY (contest_id) REFERENCES public.contests(id) ON DELETE CASCADE;


--
-- Name: user_contest_badges user_contest_badges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_contest_badges
    ADD CONSTRAINT user_contest_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_lesson_progress user_lesson_progress_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_lesson_progress
    ADD CONSTRAINT user_lesson_progress_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;


--
-- Name: user_lesson_progress user_lesson_progress_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_lesson_progress
    ADD CONSTRAINT user_lesson_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: matchmaking_queue Allow delete own matchmaking queue entry; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow delete own matchmaking queue entry" ON public.matchmaking_queue FOR DELETE TO authenticated USING ((player_id = auth.uid()));


--
-- Name: matchmaking_queue Allow insert own matchmaking queue entry; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow insert own matchmaking queue entry" ON public.matchmaking_queue FOR INSERT TO authenticated WITH CHECK ((player_id = auth.uid()));


--
-- Name: matchmaking_queue Allow read own matchmaking queue entry; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read own matchmaking queue entry" ON public.matchmaking_queue FOR SELECT TO authenticated USING ((player_id = auth.uid()));


--
-- Name: categories Anon can read active categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Anon can read active categories" ON public.categories FOR SELECT TO anon USING ((is_active = true));


--
-- Name: questions Anon can read approved questions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Anon can read approved questions" ON public.questions FOR SELECT TO anon USING ((is_approved = true));


--
-- Name: questions Approved questions are readable; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Approved questions are readable" ON public.questions FOR SELECT TO authenticated USING ((is_approved = true));


--
-- Name: categories Categories are readable; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Categories are readable" ON public.categories FOR SELECT TO authenticated USING ((is_active = true));


--
-- Name: room_players Players can join as themselves; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Players can join as themselves" ON public.room_players FOR INSERT TO authenticated WITH CHECK ((player_id = auth.uid()));


--
-- Name: room_players Players read room membership; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Players read room membership" ON public.room_players FOR SELECT TO authenticated USING (((player_id = auth.uid()) OR public.is_room_participant(room_id)));


--
-- Name: player_answers Players read their own answers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Players read their own answers" ON public.player_answers FOR SELECT TO authenticated USING ((player_id = auth.uid()));


--
-- Name: player_answers Players submit their own answers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Players submit their own answers" ON public.player_answers FOR INSERT TO authenticated WITH CHECK ((player_id = auth.uid()));


--
-- Name: profiles Profiles are readable by signed-in users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Profiles are readable by signed-in users" ON public.profiles FOR SELECT TO authenticated USING (true);


--
-- Name: room_questions Room participants can read room questions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Room participants can read room questions" ON public.room_questions FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.room_players
  WHERE ((room_players.room_id = room_questions.room_id) AND (room_players.player_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.rooms
  WHERE ((rooms.id = room_questions.room_id) AND (rooms.host_id = auth.uid()))))));


--
-- Name: rooms Room participants can read rooms; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Room participants can read rooms" ON public.rooms FOR SELECT TO authenticated USING (((host_id = auth.uid()) OR public.is_room_participant(id)));


--
-- Name: rooms Signed-in users create rooms; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Signed-in users create rooms" ON public.rooms FOR INSERT TO authenticated WITH CHECK ((host_id = auth.uid()));


--
-- Name: friend_requests Users can view incoming friend requests; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view incoming friend requests" ON public.friend_requests FOR SELECT USING ((auth.uid() = to_user_id));


--
-- Name: analytics_events Users can view own analytics; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own analytics" ON public.analytics_events FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: friends Users can view own friends; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own friends" ON public.friends FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: mission_completions Users can view own mission completions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own mission completions" ON public.mission_completions FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: spin_wheel_history Users can view own spin history; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own spin history" ON public.spin_wheel_history FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: tournament_progress Users can view own tournament progress; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own tournament progress" ON public.tournament_progress FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: profiles Users insert their own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users insert their own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK ((id = auth.uid()));


--
-- Name: favorite_questions Users manage favorites; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users manage favorites" ON public.favorite_questions TO authenticated USING ((player_id = auth.uid())) WITH CHECK ((player_id = auth.uid()));


--
-- Name: coin_transactions Users read their own coin transactions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users read their own coin transactions" ON public.coin_transactions FOR SELECT TO authenticated USING ((player_id = auth.uid()));


--
-- Name: question_reports Users report questions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users report questions" ON public.question_reports FOR INSERT TO authenticated WITH CHECK ((reporter_id = auth.uid()));


--
-- Name: profiles Users update their own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users update their own profile" ON public.profiles FOR UPDATE TO authenticated USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


--
-- Name: analytics_events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

--
-- Name: blocked_users; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

--
-- Name: blocked_users blocked_users_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY blocked_users_own ON public.blocked_users USING ((blocker_id = auth.uid())) WITH CHECK ((blocker_id = auth.uid()));


--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: coin_transactions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: contest_badges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.contest_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: contest_badges contest_badges_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY contest_badges_read ON public.contest_badges FOR SELECT USING (true);


--
-- Name: contest_entries; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.contest_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: contest_entries contest_entries_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY contest_entries_read ON public.contest_entries FOR SELECT USING (true);


--
-- Name: contests; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.contests ENABLE ROW LEVEL SECURITY;

--
-- Name: contests contests_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY contests_read ON public.contests FOR SELECT USING (true);


--
-- Name: favorite_questions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.favorite_questions ENABLE ROW LEVEL SECURITY;

--
-- Name: friend_requests; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: friends; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;

--
-- Name: league_memberships; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.league_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: league_memberships league_memberships_read_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY league_memberships_read_own ON public.league_memberships FOR SELECT TO authenticated USING ((player_id = auth.uid()));


--
-- Name: league_weeks; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.league_weeks ENABLE ROW LEVEL SECURITY;

--
-- Name: league_weeks league_weeks_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY league_weeks_read ON public.league_weeks FOR SELECT TO authenticated, anon USING (true);


--
-- Name: lesson_slides; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.lesson_slides ENABLE ROW LEVEL SECURITY;

--
-- Name: lesson_slides lesson_slides_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY lesson_slides_read ON public.lesson_slides FOR SELECT USING (true);


--
-- Name: lessons; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

--
-- Name: lessons lessons_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY lessons_read ON public.lessons FOR SELECT USING (true);


--
-- Name: matchmaking_queue; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.matchmaking_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: message_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.message_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: message_reports message_reports_insert_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY message_reports_insert_own ON public.message_reports FOR INSERT WITH CHECK ((reporter_id = auth.uid()));


--
-- Name: mission_completions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.mission_completions ENABLE ROW LEVEL SECURITY;

--
-- Name: profile_reports own profile reports; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "own profile reports" ON public.profile_reports FOR SELECT TO authenticated USING ((auth.uid() = reporter_id));


--
-- Name: player_answers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.player_answers ENABLE ROW LEVEL SECURITY;

--
-- Name: profile_cosmetic_quarantine; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profile_cosmetic_quarantine ENABLE ROW LEVEL SECURITY;

--
-- Name: profile_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profile_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: question_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.question_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: questions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

--
-- Name: room_messages; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: room_messages room_messages_member_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY room_messages_member_insert ON public.room_messages FOR INSERT TO authenticated WITH CHECK (((sender_id = auth.uid()) AND ((char_length(btrim(text)) >= 1) AND (char_length(btrim(text)) <= 500)) AND ((EXISTS ( SELECT 1
   FROM public.room_players rp
  WHERE ((rp.room_id = room_messages.room_id) AND (rp.player_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.rooms r
  WHERE ((r.id = room_messages.room_id) AND (r.host_id = auth.uid())))))));


--
-- Name: room_messages room_messages_member_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY room_messages_member_select ON public.room_messages FOR SELECT TO authenticated USING ((((EXISTS ( SELECT 1
   FROM public.room_players rp
  WHERE ((rp.room_id = room_messages.room_id) AND (rp.player_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.rooms r
  WHERE ((r.id = room_messages.room_id) AND (r.host_id = auth.uid()))))) AND (NOT (EXISTS ( SELECT 1
   FROM public.blocked_users b
  WHERE ((b.blocker_id = auth.uid()) AND (b.blocked_id = room_messages.sender_id)))))));


--
-- Name: room_players; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.room_players ENABLE ROW LEVEL SECURITY;

--
-- Name: room_questions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.room_questions ENABLE ROW LEVEL SECURITY;

--
-- Name: rooms; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

--
-- Name: shop_items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;

--
-- Name: shop_items shop_items_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY shop_items_read ON public.shop_items FOR SELECT USING (true);


--
-- Name: shop_purchases; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.shop_purchases ENABLE ROW LEVEL SECURITY;

--
-- Name: shop_purchases shop_purchases_select_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY shop_purchases_select_own ON public.shop_purchases FOR SELECT TO authenticated USING ((player_id = auth.uid()));


--
-- Name: spin_wheel_history; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.spin_wheel_history ENABLE ROW LEVEL SECURITY;

--
-- Name: suggested_questions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.suggested_questions ENABLE ROW LEVEL SECURITY;

--
-- Name: suggested_questions suggested_questions_insert_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY suggested_questions_insert_own ON public.suggested_questions FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: suggested_questions suggested_questions_read_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY suggested_questions_read_own ON public.suggested_questions FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: tournament_entries; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tournament_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: tournament_entries tournament_entries_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY tournament_entries_read ON public.tournament_entries FOR SELECT USING (true);


--
-- Name: tournament_matches; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tournament_matches ENABLE ROW LEVEL SECURITY;

--
-- Name: tournament_matches tournament_matches_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY tournament_matches_read ON public.tournament_matches FOR SELECT USING (true);


--
-- Name: tournament_progress; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tournament_progress ENABLE ROW LEVEL SECURITY;

--
-- Name: tournaments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;

--
-- Name: tournaments tournaments_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY tournaments_read ON public.tournaments FOR SELECT USING (true);


--
-- Name: user_contest_badges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_contest_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: user_contest_badges user_contest_badges_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_contest_badges_read ON public.user_contest_badges FOR SELECT USING (true);


--
-- Name: user_lesson_progress; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_lesson_progress ENABLE ROW LEVEL SECURITY;

--
-- Name: user_lesson_progress user_lesson_progress_insert_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_lesson_progress_insert_own ON public.user_lesson_progress FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: user_lesson_progress user_lesson_progress_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_lesson_progress_read ON public.user_lesson_progress FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: user_lesson_progress user_lesson_progress_update_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_lesson_progress_update_own ON public.user_lesson_progress FOR UPDATE USING ((user_id = auth.uid()));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION accept_friend_request(p_request_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.accept_friend_request(p_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.accept_friend_request(p_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.accept_friend_request(p_request_id uuid) TO service_role;


--
-- Name: FUNCTION add_friend(p_friend_id uuid, p_friend_name text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.add_friend(p_friend_id uuid, p_friend_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.add_friend(p_friend_id uuid, p_friend_name text) TO authenticated;
GRANT ALL ON FUNCTION public.add_friend(p_friend_id uuid, p_friend_name text) TO service_role;


--
-- Name: FUNCTION advance_room_question(p_room_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.advance_room_question(p_room_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.advance_room_question(p_room_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.advance_room_question(p_room_id uuid) TO service_role;


--
-- Name: FUNCTION advance_tournament(p_tournament_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.advance_tournament(p_tournament_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.advance_tournament(p_tournament_id uuid) TO service_role;


--
-- Name: FUNCTION assign_player_tag(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.assign_player_tag() FROM PUBLIC;
GRANT ALL ON FUNCTION public.assign_player_tag() TO authenticated;
GRANT ALL ON FUNCTION public.assign_player_tag() TO service_role;


--
-- Name: FUNCTION award_spin_coins(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.award_spin_coins() FROM PUBLIC;
GRANT ALL ON FUNCTION public.award_spin_coins() TO authenticated;
GRANT ALL ON FUNCTION public.award_spin_coins() TO service_role;


--
-- Name: FUNCTION award_xp_delta(p_delta integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.award_xp_delta(p_delta integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.award_xp_delta(p_delta integer) TO service_role;
GRANT ALL ON FUNCTION public.award_xp_delta(p_delta integer) TO authenticated;


--
-- Name: FUNCTION block_player(p_blocked_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.block_player(p_blocked_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.block_player(p_blocked_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.block_player(p_blocked_id uuid) TO service_role;


--
-- Name: FUNCTION can_spin_today(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.can_spin_today() FROM PUBLIC;
GRANT ALL ON FUNCTION public.can_spin_today() TO authenticated;
GRANT ALL ON FUNCTION public.can_spin_today() TO service_role;


--
-- Name: FUNCTION chat_message_is_clean(p_text text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.chat_message_is_clean(p_text text) TO anon;
GRANT ALL ON FUNCTION public.chat_message_is_clean(p_text text) TO authenticated;
GRANT ALL ON FUNCTION public.chat_message_is_clean(p_text text) TO service_role;


--
-- Name: FUNCTION claim_contest_reward(p_contest_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.claim_contest_reward(p_contest_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.claim_contest_reward(p_contest_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.claim_contest_reward(p_contest_id uuid) TO authenticated;


--
-- Name: FUNCTION claim_daily_spin(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.claim_daily_spin() FROM PUBLIC;
GRANT ALL ON FUNCTION public.claim_daily_spin() TO authenticated;
GRANT ALL ON FUNCTION public.claim_daily_spin() TO service_role;


--
-- Name: FUNCTION claim_extra_spin(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.claim_extra_spin() FROM PUBLIC;
GRANT ALL ON FUNCTION public.claim_extra_spin() TO authenticated;
GRANT ALL ON FUNCTION public.claim_extra_spin() TO service_role;


--
-- Name: FUNCTION claim_mission_reward(p_mission_key text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.claim_mission_reward(p_mission_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.claim_mission_reward(p_mission_key text) TO authenticated;
GRANT ALL ON FUNCTION public.claim_mission_reward(p_mission_key text) TO service_role;


--
-- Name: FUNCTION claim_quiz_reward(p_room_id uuid, p_score integer, p_correct_count integer, p_best_streak integer, p_total_questions integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.claim_quiz_reward(p_room_id uuid, p_score integer, p_correct_count integer, p_best_streak integer, p_total_questions integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.claim_quiz_reward(p_room_id uuid, p_score integer, p_correct_count integer, p_best_streak integer, p_total_questions integer) TO authenticated;
GRANT ALL ON FUNCTION public.claim_quiz_reward(p_room_id uuid, p_score integer, p_correct_count integer, p_best_streak integer, p_total_questions integer) TO service_role;


--
-- Name: FUNCTION claim_tournament_reward(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.claim_tournament_reward() FROM PUBLIC;
GRANT ALL ON FUNCTION public.claim_tournament_reward() TO authenticated;
GRANT ALL ON FUNCTION public.claim_tournament_reward() TO service_role;


--
-- Name: FUNCTION cleanup_stale_rooms(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.cleanup_stale_rooms() FROM PUBLIC;
GRANT ALL ON FUNCTION public.cleanup_stale_rooms() TO authenticated;
GRANT ALL ON FUNCTION public.cleanup_stale_rooms() TO service_role;


--
-- Name: FUNCTION delete_my_account(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT ALL ON FUNCTION public.delete_my_account() TO service_role;
GRANT ALL ON FUNCTION public.delete_my_account() TO authenticated;


--
-- Name: FUNCTION enforce_chat_moderation(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.enforce_chat_moderation() FROM PUBLIC;
GRANT ALL ON FUNCTION public.enforce_chat_moderation() TO authenticated;
GRANT ALL ON FUNCTION public.enforce_chat_moderation() TO service_role;


--
-- Name: FUNCTION enforce_current_room_question(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.enforce_current_room_question() FROM PUBLIC;
GRANT ALL ON FUNCTION public.enforce_current_room_question() TO authenticated;
GRANT ALL ON FUNCTION public.enforce_current_room_question() TO service_role;


--
-- Name: FUNCTION enforce_display_name_policy(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.enforce_display_name_policy() TO anon;
GRANT ALL ON FUNCTION public.enforce_display_name_policy() TO authenticated;
GRANT ALL ON FUNCTION public.enforce_display_name_policy() TO service_role;


--
-- Name: FUNCTION finalize_weekly_league(p_week date); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.finalize_weekly_league(p_week date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.finalize_weekly_league(p_week date) TO authenticated;
GRANT ALL ON FUNCTION public.finalize_weekly_league(p_week date) TO service_role;


--
-- Name: FUNCTION finish_room_game(p_room_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.finish_room_game(p_room_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.finish_room_game(p_room_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.finish_room_game(p_room_id uuid) TO service_role;


--
-- Name: FUNCTION freeze_player_tag(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.freeze_player_tag() TO anon;
GRANT ALL ON FUNCTION public.freeze_player_tag() TO authenticated;
GRANT ALL ON FUNCTION public.freeze_player_tag() TO service_role;


--
-- Name: FUNCTION generate_player_tag(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.generate_player_tag() FROM PUBLIC;
GRANT ALL ON FUNCTION public.generate_player_tag() TO service_role;


--
-- Name: FUNCTION get_contest_leaderboard(p_contest_id uuid, p_limit integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_contest_leaderboard(p_contest_id uuid, p_limit integer) TO anon;
GRANT ALL ON FUNCTION public.get_contest_leaderboard(p_contest_id uuid, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_contest_leaderboard(p_contest_id uuid, p_limit integer) TO service_role;


--
-- Name: FUNCTION get_leaderboard(p_days integer, p_limit integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.get_leaderboard(p_days integer, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_leaderboard(p_days integer, p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_leaderboard(p_days integer, p_limit integer) TO service_role;


--
-- Name: FUNCTION get_my_league_state(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.get_my_league_state() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_my_league_state() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_league_state() TO service_role;


--
-- Name: FUNCTION get_room_questions(p_room_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.get_room_questions(p_room_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_room_questions(p_room_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_room_questions(p_room_id uuid) TO service_role;


--
-- Name: FUNCTION get_today_contest(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_today_contest() TO anon;
GRANT ALL ON FUNCTION public.get_today_contest() TO authenticated;
GRANT ALL ON FUNCTION public.get_today_contest() TO service_role;


--
-- Name: FUNCTION get_tournament_bracket(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.get_tournament_bracket() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_tournament_bracket() TO authenticated;
GRANT ALL ON FUNCTION public.get_tournament_bracket() TO service_role;


--
-- Name: FUNCTION is_room_participant(p_room_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.is_room_participant(p_room_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.is_room_participant(p_room_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_room_participant(p_room_id uuid) TO service_role;


--
-- Name: FUNCTION join_matchmaking(p_category_name text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.join_matchmaking(p_category_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.join_matchmaking(p_category_name text) TO authenticated;
GRANT ALL ON FUNCTION public.join_matchmaking(p_category_name text) TO service_role;


--
-- Name: FUNCTION join_room_by_code(p_code text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.join_room_by_code(p_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.join_room_by_code(p_code text) TO authenticated;
GRANT ALL ON FUNCTION public.join_room_by_code(p_code text) TO service_role;


--
-- Name: FUNCTION join_tournament(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.join_tournament() FROM PUBLIC;
GRANT ALL ON FUNCTION public.join_tournament() TO authenticated;
GRANT ALL ON FUNCTION public.join_tournament() TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE room_players; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.room_players TO anon;
GRANT ALL ON TABLE public.room_players TO authenticated;
GRANT ALL ON TABLE public.room_players TO service_role;


--
-- Name: TABLE leaderboard_entries; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.leaderboard_entries TO anon;
GRANT ALL ON TABLE public.leaderboard_entries TO authenticated;
GRANT ALL ON TABLE public.leaderboard_entries TO service_role;


--
-- Name: FUNCTION leaderboard_visible(p_limit integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.leaderboard_visible(p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leaderboard_visible(p_limit integer) TO authenticated;
GRANT ALL ON FUNCTION public.leaderboard_visible(p_limit integer) TO service_role;


--
-- Name: FUNCTION league_tier_for_rank(p_rank integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.league_tier_for_rank(p_rank integer) TO anon;
GRANT ALL ON FUNCTION public.league_tier_for_rank(p_rank integer) TO authenticated;
GRANT ALL ON FUNCTION public.league_tier_for_rank(p_rank integer) TO service_role;


--
-- Name: FUNCTION league_week_start(ts timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.league_week_start(ts timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.league_week_start(ts timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.league_week_start(ts timestamp with time zone) TO service_role;


--
-- Name: FUNCTION list_friends(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.list_friends() TO anon;
GRANT ALL ON FUNCTION public.list_friends() TO authenticated;
GRANT ALL ON FUNCTION public.list_friends() TO service_role;


--
-- Name: FUNCTION list_pending_friend_requests(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.list_pending_friend_requests() TO anon;
GRANT ALL ON FUNCTION public.list_pending_friend_requests() TO authenticated;
GRANT ALL ON FUNCTION public.list_pending_friend_requests() TO service_role;


--
-- Name: FUNCTION load_lesson(p_lesson_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.load_lesson(p_lesson_id uuid) TO anon;
GRANT ALL ON FUNCTION public.load_lesson(p_lesson_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.load_lesson(p_lesson_id uuid) TO service_role;


--
-- Name: FUNCTION load_lesson_slides(p_lesson_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.load_lesson_slides(p_lesson_id uuid) TO anon;
GRANT ALL ON FUNCTION public.load_lesson_slides(p_lesson_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.load_lesson_slides(p_lesson_id uuid) TO service_role;


--
-- Name: FUNCTION load_lessons_by_category(p_category text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.load_lessons_by_category(p_category text) TO anon;
GRANT ALL ON FUNCTION public.load_lessons_by_category(p_category text) TO authenticated;
GRANT ALL ON FUNCTION public.load_lessons_by_category(p_category text) TO service_role;


--
-- Name: FUNCTION log_analytics_event(p_event_name text, p_event_params jsonb); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.log_analytics_event(p_event_name text, p_event_params jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.log_analytics_event(p_event_name text, p_event_params jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.log_analytics_event(p_event_name text, p_event_params jsonb) TO service_role;


--
-- Name: FUNCTION mark_lesson_completed(p_lesson_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.mark_lesson_completed(p_lesson_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.mark_lesson_completed(p_lesson_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.mark_lesson_completed(p_lesson_id uuid) TO service_role;


--
-- Name: TABLE suggested_questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.suggested_questions TO anon;
GRANT ALL ON TABLE public.suggested_questions TO authenticated;
GRANT ALL ON TABLE public.suggested_questions TO service_role;


--
-- Name: FUNCTION moderate_suggested_question(p_question_id uuid, p_status text, p_review_note text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.moderate_suggested_question(p_question_id uuid, p_status text, p_review_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.moderate_suggested_question(p_question_id uuid, p_status text, p_review_note text) TO service_role;


--
-- Name: FUNCTION profiles_client_write_guard(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.profiles_client_write_guard() TO anon;
GRANT ALL ON FUNCTION public.profiles_client_write_guard() TO authenticated;
GRANT ALL ON FUNCTION public.profiles_client_write_guard() TO service_role;


--
-- Name: FUNCTION protect_paid_profile_cosmetics(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.protect_paid_profile_cosmetics() FROM PUBLIC;
GRANT ALL ON FUNCTION public.protect_paid_profile_cosmetics() TO authenticated;
GRANT ALL ON FUNCTION public.protect_paid_profile_cosmetics() TO service_role;


--
-- Name: FUNCTION reject_friend_request(p_request_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.reject_friend_request(p_request_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.reject_friend_request(p_request_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.reject_friend_request(p_request_id uuid) TO service_role;


--
-- Name: FUNCTION report_player_profile(p_reported_id uuid, p_reason text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.report_player_profile(p_reported_id uuid, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.report_player_profile(p_reported_id uuid, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.report_player_profile(p_reported_id uuid, p_reason text) TO service_role;


--
-- Name: FUNCTION report_question(p_question_id text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.report_question(p_question_id text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.report_question(p_question_id text) TO authenticated;
GRANT ALL ON FUNCTION public.report_question(p_question_id text) TO service_role;


--
-- Name: FUNCTION report_room_message(p_message_id uuid, p_reason text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.report_room_message(p_message_id uuid, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.report_room_message(p_message_id uuid, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.report_room_message(p_message_id uuid, p_reason text) TO service_role;


--
-- Name: FUNCTION resolve_expired_tournament_matches(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.resolve_expired_tournament_matches() FROM PUBLIC;
GRANT ALL ON FUNCTION public.resolve_expired_tournament_matches() TO service_role;


--
-- Name: FUNCTION rls_auto_enable(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO authenticated;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;


--
-- Name: FUNCTION room_players_client_write_guard(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.room_players_client_write_guard() TO anon;
GRANT ALL ON FUNCTION public.room_players_client_write_guard() TO authenticated;
GRANT ALL ON FUNCTION public.room_players_client_write_guard() TO service_role;


--
-- Name: FUNCTION save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[]); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[]) TO authenticated;
GRANT ALL ON FUNCTION public.save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[]) TO service_role;


--
-- Name: FUNCTION search_profiles(p_query text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.search_profiles(p_query text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.search_profiles(p_query text) TO authenticated;
GRANT ALL ON FUNCTION public.search_profiles(p_query text) TO service_role;


--
-- Name: FUNCTION set_room_ready(p_room_id uuid, p_is_ready boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.set_room_ready(p_room_id uuid, p_is_ready boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_room_ready(p_room_id uuid, p_is_ready boolean) TO authenticated;
GRANT ALL ON FUNCTION public.set_room_ready(p_room_id uuid, p_is_ready boolean) TO service_role;


--
-- Name: FUNCTION spend_coins(p_amount integer, p_reason text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.spend_coins(p_amount integer, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.spend_coins(p_amount integer, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.spend_coins(p_amount integer, p_reason text) TO service_role;


--
-- Name: FUNCTION start_due_tournaments(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.start_due_tournaments() FROM PUBLIC;
GRANT ALL ON FUNCTION public.start_due_tournaments() TO service_role;


--
-- Name: FUNCTION start_room_game(p_room_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.start_room_game(p_room_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.start_room_game(p_room_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.start_room_game(p_room_id uuid) TO service_role;


--
-- Name: FUNCTION start_tournament(p_tournament_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.start_tournament(p_tournament_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.start_tournament(p_tournament_id uuid) TO service_role;


--
-- Name: FUNCTION submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer) TO authenticated;
GRANT ALL ON FUNCTION public.submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer) TO service_role;


--
-- Name: FUNCTION submit_contest_entry(p_contest_id uuid, p_correct_count integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.submit_contest_entry(p_contest_id uuid, p_correct_count integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_contest_entry(p_contest_id uuid, p_correct_count integer) TO service_role;
GRANT ALL ON FUNCTION public.submit_contest_entry(p_contest_id uuid, p_correct_count integer) TO authenticated;


--
-- Name: FUNCTION submit_tournament_match(p_match_id uuid, p_score integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.submit_tournament_match(p_match_id uuid, p_score integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.submit_tournament_match(p_match_id uuid, p_score integer) TO authenticated;
GRANT ALL ON FUNCTION public.submit_tournament_match(p_match_id uuid, p_score integer) TO service_role;


--
-- Name: FUNCTION sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer) TO authenticated;
GRANT ALL ON FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer) TO service_role;


--
-- Name: FUNCTION unblock_player(p_blocked_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.unblock_player(p_blocked_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.unblock_player(p_blocked_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.unblock_player(p_blocked_id uuid) TO service_role;


--
-- Name: FUNCTION zk_display_name_is_clean(p_name text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.zk_display_name_is_clean(p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.zk_display_name_is_clean(p_name text) TO authenticated;
GRANT ALL ON FUNCTION public.zk_display_name_is_clean(p_name text) TO service_role;


--
-- Name: FUNCTION zk_normalize_text(p_input text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.zk_normalize_text(p_input text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.zk_normalize_text(p_input text) TO authenticated;
GRANT ALL ON FUNCTION public.zk_normalize_text(p_input text) TO service_role;


--
-- Name: TABLE analytics_events; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.analytics_events TO anon;
GRANT ALL ON TABLE public.analytics_events TO authenticated;
GRANT ALL ON TABLE public.analytics_events TO service_role;


--
-- Name: TABLE blocked_users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.blocked_users TO anon;
GRANT ALL ON TABLE public.blocked_users TO authenticated;
GRANT ALL ON TABLE public.blocked_users TO service_role;


--
-- Name: TABLE categories; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.categories TO anon;
GRANT ALL ON TABLE public.categories TO authenticated;
GRANT ALL ON TABLE public.categories TO service_role;


--
-- Name: TABLE coin_transactions; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.coin_transactions TO anon;
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.coin_transactions TO authenticated;
GRANT ALL ON TABLE public.coin_transactions TO service_role;


--
-- Name: TABLE contest_badges; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.contest_badges TO anon;
GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.contest_badges TO authenticated;
GRANT ALL ON TABLE public.contest_badges TO service_role;


--
-- Name: TABLE contest_entries; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.contest_entries TO anon;
GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.contest_entries TO authenticated;
GRANT ALL ON TABLE public.contest_entries TO service_role;


--
-- Name: TABLE contests; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.contests TO anon;
GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.contests TO authenticated;
GRANT ALL ON TABLE public.contests TO service_role;


--
-- Name: TABLE favorite_questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.favorite_questions TO anon;
GRANT ALL ON TABLE public.favorite_questions TO authenticated;
GRANT ALL ON TABLE public.favorite_questions TO service_role;


--
-- Name: TABLE friend_requests; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.friend_requests TO anon;
GRANT ALL ON TABLE public.friend_requests TO authenticated;
GRANT ALL ON TABLE public.friend_requests TO service_role;


--
-- Name: TABLE friends; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.friends TO anon;
GRANT ALL ON TABLE public.friends TO authenticated;
GRANT ALL ON TABLE public.friends TO service_role;


--
-- Name: TABLE league_memberships; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.league_memberships TO anon;
GRANT ALL ON TABLE public.league_memberships TO authenticated;
GRANT ALL ON TABLE public.league_memberships TO service_role;


--
-- Name: TABLE league_weeks; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.league_weeks TO anon;
GRANT ALL ON TABLE public.league_weeks TO authenticated;
GRANT ALL ON TABLE public.league_weeks TO service_role;


--
-- Name: TABLE lesson_slides; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.lesson_slides TO anon;
GRANT ALL ON TABLE public.lesson_slides TO authenticated;
GRANT ALL ON TABLE public.lesson_slides TO service_role;


--
-- Name: TABLE lessons; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.lessons TO anon;
GRANT ALL ON TABLE public.lessons TO authenticated;
GRANT ALL ON TABLE public.lessons TO service_role;


--
-- Name: TABLE matchmaking_queue; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.matchmaking_queue TO anon;
GRANT ALL ON TABLE public.matchmaking_queue TO authenticated;
GRANT ALL ON TABLE public.matchmaking_queue TO service_role;


--
-- Name: TABLE message_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.message_reports TO anon;
GRANT ALL ON TABLE public.message_reports TO authenticated;
GRANT ALL ON TABLE public.message_reports TO service_role;


--
-- Name: TABLE mission_completions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mission_completions TO anon;
GRANT ALL ON TABLE public.mission_completions TO authenticated;
GRANT ALL ON TABLE public.mission_completions TO service_role;


--
-- Name: TABLE player_answers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.player_answers TO anon;
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.player_answers TO authenticated;
GRANT ALL ON TABLE public.player_answers TO service_role;


--
-- Name: TABLE profile_cosmetic_quarantine; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profile_cosmetic_quarantine TO service_role;


--
-- Name: TABLE profile_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profile_reports TO service_role;


--
-- Name: TABLE question_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.question_reports TO anon;
GRANT ALL ON TABLE public.question_reports TO authenticated;
GRANT ALL ON TABLE public.question_reports TO service_role;


--
-- Name: TABLE questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE public.questions TO anon;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE public.questions TO authenticated;
GRANT ALL ON TABLE public.questions TO service_role;


--
-- Name: TABLE quiz_eligible_questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE public.quiz_eligible_questions TO anon;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE public.quiz_eligible_questions TO authenticated;
GRANT ALL ON TABLE public.quiz_eligible_questions TO service_role;


--
-- Name: TABLE quiz_public_questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.quiz_public_questions TO anon;
GRANT ALL ON TABLE public.quiz_public_questions TO authenticated;
GRANT ALL ON TABLE public.quiz_public_questions TO service_role;


--
-- Name: TABLE room_messages; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.room_messages TO anon;
GRANT ALL ON TABLE public.room_messages TO authenticated;
GRANT ALL ON TABLE public.room_messages TO service_role;


--
-- Name: TABLE room_questions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.room_questions TO anon;
GRANT ALL ON TABLE public.room_questions TO authenticated;
GRANT ALL ON TABLE public.room_questions TO service_role;


--
-- Name: TABLE rooms; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.rooms TO anon;
GRANT ALL ON TABLE public.rooms TO authenticated;
GRANT ALL ON TABLE public.rooms TO service_role;


--
-- Name: TABLE shop_items; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.shop_items TO anon;
GRANT ALL ON TABLE public.shop_items TO authenticated;
GRANT ALL ON TABLE public.shop_items TO service_role;


--
-- Name: TABLE shop_purchases; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.shop_purchases TO service_role;
GRANT SELECT ON TABLE public.shop_purchases TO authenticated;


--
-- Name: TABLE spin_wheel_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.spin_wheel_history TO anon;
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.spin_wheel_history TO authenticated;
GRANT ALL ON TABLE public.spin_wheel_history TO service_role;


--
-- Name: TABLE tournament_entries; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tournament_entries TO anon;
GRANT ALL ON TABLE public.tournament_entries TO authenticated;
GRANT ALL ON TABLE public.tournament_entries TO service_role;


--
-- Name: TABLE tournament_matches; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tournament_matches TO anon;
GRANT ALL ON TABLE public.tournament_matches TO authenticated;
GRANT ALL ON TABLE public.tournament_matches TO service_role;


--
-- Name: TABLE tournament_progress; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tournament_progress TO anon;
GRANT ALL ON TABLE public.tournament_progress TO authenticated;
GRANT ALL ON TABLE public.tournament_progress TO service_role;


--
-- Name: TABLE tournaments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tournaments TO anon;
GRANT ALL ON TABLE public.tournaments TO authenticated;
GRANT ALL ON TABLE public.tournaments TO service_role;


--
-- Name: TABLE user_contest_badges; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.user_contest_badges TO anon;
GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.user_contest_badges TO authenticated;
GRANT ALL ON TABLE public.user_contest_badges TO service_role;


--
-- Name: TABLE user_lesson_progress; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_lesson_progress TO anon;
GRANT ALL ON TABLE public.user_lesson_progress TO authenticated;
GRANT ALL ON TABLE public.user_lesson_progress TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;



--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;



--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;



--
-- PostgreSQL database dump complete
--
