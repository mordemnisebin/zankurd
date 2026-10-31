-- Generated from the live catalog; requires reviewed diff and owner approval.
-- Smoke in a transaction with ROLLBACK before production COMMIT.
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE public.rooms IN ACCESS EXCLUSIVE MODE;
DO $room_limits_guard$
BEGIN
if md5(pg_get_functiondef('public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)'::regprocedure)) <> '6809d77c75f5688860c57d239a46ca18' then
  raise exception 'room limits: live function source changed; export and review again';
end if;
if (select count(*) from pg_constraint c
  where c.conrelid = 'public.rooms'::regclass and c.contype = 'c'
  and pg_get_constraintdef(c.oid) ~ '(question_count|seconds_per_question)') <> 2 then
  raise exception 'room limits: unexpected live constraints';
end if;
if not exists (select 1 from pg_constraint c
  where c.conrelid = 'public.rooms'::regclass
  and c.conname = 'rooms_question_count_check'
  and pg_get_constraintdef(c.oid) = 'CHECK (((question_count >= 3) AND (question_count <= 30)))') then
  raise exception 'room limits: live constraint changed; export and review again';
end if;
if not exists (select 1 from pg_constraint c
  where c.conrelid = 'public.rooms'::regclass
  and c.conname = 'rooms_seconds_per_question_check'
  and pg_get_constraintdef(c.oid) = 'CHECK (((seconds_per_question >= 5) AND (seconds_per_question <= 60)))') then
  raise exception 'room limits: live constraint changed; export and review again';
end if;
END;
$room_limits_guard$;
CREATE OR REPLACE FUNCTION public.create_online_room_impl(p_category_names text[], p_seconds_per_question integer, p_question_count integer, p_entry_fee integer, p_max_players integer, p_legacy_code boolean)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_id uuid;
  v_category_ids uuid[];
  v_category_name text;
  v_wanted text[];
  v_found_ids uuid[];
  v_found_names text[];
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
     or p_seconds_per_question not in (10, 15, 20, 30, 45, 60, 90, 120) then
    raise exception 'Unsupported seconds per question';
  end if;

  if p_question_count is null
     or p_question_count not in (5, 10, 15, 20, 25, 30, 40, 50) then
    raise exception 'Unsupported question count';
  end if;

  if p_entry_fee is null
     or p_entry_fee not in (0, 25, 50, 100) then
    raise exception 'Unsupported entry fee';
  end if;

  -- Kapasite: 2 = ikili özel oda, 4..50 = kalabalık oda.
  if p_max_players is null
     or p_max_players not in (2, 4, 8, 16, 30, 50) then
    raise exception 'Unsupported max players';
  end if;

  -- Kategori seçimi (2026-10-18): NULL ya da boş dizi = Karışık (hepsi);
  -- tek ad = eski davranış (category_id dolu); iki ya da daha çok ad =
  -- category_ids dolu, category_id NULL. Boş/NULL eleman reddedilir.
  if p_category_names is null or cardinality(p_category_names) = 0 then
    v_category_name := 'Tevlihev';
  else
    if cardinality(p_category_names) > 12
       or exists (
         select 1 from unnest(p_category_names) n
         where nullif(btrim(n), '') is null
       ) then
      raise exception 'Category is not available';
    end if;

    select array_agg(distinct upper(btrim(n))) into v_wanted
    from unnest(p_category_names) n;

    select array_agg(c.id order by c.name), array_agg(c.name order by c.name)
    into v_found_ids, v_found_names
    from public.categories c
    where upper(c.name) = any(v_wanted)
      and c.is_active = true;

    if v_found_ids is null
       or cardinality(v_found_ids) <> cardinality(v_wanted) then
      raise exception 'Category is not available';
    end if;

    if cardinality(v_found_ids) = 1 then
      v_category_id := v_found_ids[1];
    else
      v_category_ids := v_found_ids;
    end if;
    v_category_name := array_to_string(v_found_names, ', ');
  end if;

  -- spend_coins ve buy_streak_freeze ile aynı profil satır kilidini al
  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform 1 from public.profiles where id = v_uid for update;

  -- Bakiye kontrolü kilit alındıktan sonra yapılır (çift harcama yarış durumu önlemi)
  if p_entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < p_entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  -- Aktif oda varsa snapshot'ı dön
  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    r.is_custom,
    r.max_players,
    public.room_category_label(r.category_ids, c.name) as category_name
  into v_existing
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id and rp.player_id = v_uid
   and rp.left_at is null
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
      'max_players', v_existing.max_players,
      'is_custom', v_existing.is_custom,
      'status', v_existing.status
    );
  end if;

  loop
    v_attempt := v_attempt + 1;
    -- 6 haneli rakam kodu (ilk hane 1-9): sesli söylenir. Benzersizlik
    -- yalnız AÇIK odalar arasındadır (rooms_open_upper_code_uidx).
    if p_legacy_code then
      -- Mağazadaki eski istemciler yalnız ZK-+10 onaltılık kodu katılımda
      -- kabul eder: eski 5 parametreli RPC bunu AYNEN üretmeye devam eder.
      v_room_code := 'ZK-' || upper(
        substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
      );
    else
      v_room_code := (1 + floor(random() * 9))::integer::text
        || lpad(floor(random() * 100000)::integer::text, 5, '0');
    end if;

    begin
      insert into public.rooms (
        code,
        host_id,
        category_id,
        category_ids,
        question_count,
        seconds_per_question,
        entry_fee,
        is_custom,
        max_players,
        status
      ) values (
        v_room_code,
        v_uid,
        v_category_id,
        v_category_ids,
        p_question_count,
        p_seconds_per_question,
        p_entry_fee,
        true,
        p_max_players,
        'lobby'
      ) returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 20 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room_id, v_uid, true);

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
    'max_players', p_max_players,
    'is_custom', true,
    'status', 'lobby'
  );
end;
$function$;
ALTER TABLE public.rooms DROP CONSTRAINT "rooms_question_count_check";
ALTER TABLE public.rooms ADD CONSTRAINT "rooms_question_count_check" CHECK (((question_count >= 3) AND (question_count <= 50)));
ALTER TABLE public.rooms DROP CONSTRAINT "rooms_seconds_per_question_check";
ALTER TABLE public.rooms ADD CONSTRAINT "rooms_seconds_per_question_check" CHECK (((seconds_per_question >= 5) AND (seconds_per_question <= 120)));
COMMIT;
