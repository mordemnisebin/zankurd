-- ZanKurd: Özelleştirilebilir Oda Kurma (Kategori, Soru Sayısı, Süre, Bahis/Giriş Ücreti)
-- ve Çok Oyunculu Oyunlaştırma Güncellemesi.
--
-- Bu göç:
-- 1. `rooms` tablosuna `entry_fee` kolonunu ekler (varsayılan: 0).
-- 2. `create_online_room` fonksiyonunu `p_question_count` ve `p_entry_fee` parametrelerini
--    destekleyecek şekilde günceller.
-- 3. `join_room_by_code` fonksiyonunun `entry_fee` döndürmesini ve bakiye kontrolünü sağlar.
-- 4. `claim_quiz_reward` fonksiyonunun ücretli odalarda kazanan oyuncuya bahis havuzunu
--    (veya beraberlik durumunda iadeyi) teslim etmesini sağlar.
-- 5. Fonksiyonları `search_path = public` ile güvenliğe alır.

begin;

alter table public.rooms
  add column if not exists entry_fee integer not null default 0;

-- Eski fonksiyonu düşür (imza değişikliği)
drop function if exists public.create_online_room(text, integer);
drop function if exists public.create_online_room(text, integer, integer, integer);

create or replace function public.create_online_room(
  p_category_name text,
  p_seconds_per_question integer,
  p_question_count integer default 10,
  p_entry_fee integer default 0
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_category_id uuid;
  v_category_name text;
  v_existing record;
  v_room_id uuid;
  v_room_code text;
  v_attempt integer := 0;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_seconds_per_question is null
     or p_seconds_per_question not in (10, 15, 20, 30, 45, 60) then
    raise exception 'Unsupported seconds per question';
  end if;

  if p_question_count is null
     or p_question_count not in (5, 10, 15) then
    raise exception 'Unsupported question count';
  end if;

  if p_entry_fee is null
     or p_entry_fee not in (0, 25, 50, 100) then
    raise exception 'Unsupported entry fee';
  end if;

  -- Bakiye kontrolü (ücretli oda için)
  if p_entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < p_entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  select c.id, c.name
  into v_category_id, v_category_name
  from public.categories c
  where upper(c.name) = upper(trim(p_category_name))
    and c.is_active = true
  limit 1;

  if v_category_id is null then
    raise exception 'Category is not available';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Aktif oda varsa snapshot'ı dön
  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    coalesce(c.name, 'Ziman') as category_name
  into v_existing
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id and rp.player_id = v_uid
  left join public.categories c on c.id = r.category_id
  where r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    delete from public.matchmaking_queue mq
    where mq.player_id = v_uid
      and mq.room_id is null;

    return json_build_object(
      'room_id', v_existing.id,
      'code', v_existing.code,
      'host_id', v_existing.host_id,
      'category_name', v_existing.category_name,
      'question_count', v_existing.question_count,
      'seconds_per_question', v_existing.seconds_per_question,
      'entry_fee', v_existing.entry_fee,
      'status', v_existing.status
    );
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_room_code := 'ZK-' || upper(
      substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
    );

    begin
      insert into public.rooms (
        code,
        host_id,
        category_id,
        question_count,
        seconds_per_question,
        entry_fee,
        status
      ) values (
        v_room_code,
        v_uid,
        v_category_id,
        p_question_count,
        p_seconds_per_question,
        p_entry_fee,
        'lobby'
      ) returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room_id, v_uid, true);

  -- Giriş ücretini BURADA düş. Kontrol tek başına yetmez: ödül tarafı
  -- kazanana `entry_fee * 2` yazıyor, yani ücret hiç tahsil edilmezse her
  -- ücretli maç yoktan `2 x entry_fee` jeton BASAR ve döngü sınırsız
  -- zenginleşmeye açılır. Düşme oda yaratıldıktan sonra yapılır ki oda
  -- kurulamazsa oyuncudan para gitmesin (hepsi tek transaction içinde).
  if p_entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -p_entry_fee, 'room_entry_fee');
  end if;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room_id,
    'code', v_room_code,
    'host_id', v_uid,
    'category_name', v_category_name,
    'question_count', p_question_count,
    'seconds_per_question', p_seconds_per_question,
    'entry_fee', p_entry_fee,
    'status', 'lobby'
  );
end;
$$;

revoke all on function public.create_online_room(text, integer, integer, integer)
  from public, anon;
grant execute on function public.create_online_room(text, integer, integer, integer)
  to authenticated;

-- join_room_by_code güncellemesi: entry_fee döndürme ve kontrol
create or replace function public.join_room_by_code(
  p_code text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_existing_room_id uuid;
  v_player_count integer;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where upper(r.code) = upper(trim(p_code))
    and r.status = 'lobby'
  limit 1
  for update of r;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  if v_existing_room_id is not null
     and v_existing_room_id <> v_room.id then
    raise exception 'Player is already in another live room';
  end if;

  -- Bakiye kontrolü (ücretli oda için)
  if v_room.entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < v_room.entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  if exists (
    select 1
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.player_id = v_uid
  ) then
    return json_build_object(
      'room_id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'entry_fee', v_room.entry_fee,
      'category_name', v_room.category_name
    );
  end if;

  select count(*)::integer into v_player_count
  from public.room_players rp
  where rp.room_id = v_room.id;

  if v_player_count >= 2 then
    raise exception 'Room is full';
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  -- Katılan oyuncunun ücreti de burada düşer; iki taraf da ödemezse havuz
  -- diye bir şey olmaz, yalnız ödül olur.
  if v_room.entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -v_room.entry_fee, 'room_entry_fee');
  end if;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'entry_fee', v_room.entry_fee,
    'category_name', v_room.category_name
  );
end;
$$;

revoke all on function public.join_room_by_code(text) from public, anon;
grant execute on function public.join_room_by_code(text) to authenticated;

-- claim_quiz_reward güncellemesi: ücretli odada kazananın bahis havuzunu alması
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
  v_room_ended_reason text;
  v_current_question_index integer;
  v_room_score integer;
  v_correct_count integer;
  v_total_questions integer;
  v_answer_count integer;
  v_amount integer;
  v_reason text;
  v_entry_fee integer := 0;
  v_winner_id uuid := null;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_player_id::text, 0));

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

  select r.status, r.ended_reason, r.current_question_index, coalesce(r.entry_fee, 0)
  into v_room_status, v_room_ended_reason, v_current_question_index, v_entry_fee
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id
   and rp.player_id = v_player_id
  where r.id = p_room_id
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  if v_room_status <> 'finished' then
    return jsonb_build_object('amount', 0, 'room_not_finished', true);
  end if;

  if v_room_ended_reason is distinct from 'completed' then
    return jsonb_build_object(
      'amount', 0,
      'room_not_completed', true,
      'ended_reason', v_room_ended_reason
    );
  end if;

  select count(*)::integer into v_total_questions
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_total_questions < 1
     or coalesce(v_current_question_index, -1) < v_total_questions then
    return jsonb_build_object(
      'amount', 0,
      'room_progress_incomplete', true
    );
  end if;

  select
    count(*)::integer,
    count(*) filter (where pa.is_correct)::integer,
    coalesce(sum(pa.points_awarded), 0)::integer
  into v_answer_count, v_correct_count, v_room_score
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id
   and rq.question_id = pa.question_id
  where pa.room_id = p_room_id
    and pa.player_id = v_player_id;

  if v_answer_count <> v_total_questions then
    return jsonb_build_object('amount', 0, 'answers_incomplete', true);
  end if;

  v_reason := 'quiz_complete:room=' || p_room_id::text;
  select max(coin_tx.amount)::integer
  into v_amount
  from public.coin_transactions coin_tx
  where coin_tx.player_id = v_player_id
    and coin_tx.reason = v_reason;
  if v_amount is not null then
    return jsonb_build_object(
      'amount', v_amount,
      'already_claimed', true
    );
  end if;

  v_amount :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_room_score / 80);

  -- Ücretli odada bahis havuzu ödülü
  if v_entry_fee > 0 then
    select case
      when min(rp.score) = max(rp.score) then null
      else (array_agg(rp.player_id order by rp.score desc, rp.player_id))[1]
    end
    into v_winner_id
    from public.room_players rp
    where rp.room_id = p_room_id;

    if v_winner_id = v_player_id then
      v_amount := v_amount + (v_entry_fee * 2);
    elsif v_winner_id is null then
      v_amount := v_amount + v_entry_fee;
    end if;
  end if;

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
) from public, anon, authenticated;
grant execute on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) to authenticated;

commit;
