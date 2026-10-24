-- =====================================================================
-- 2026-10-16_indeks_ve_kilit_sertlestirme.sql
--
-- 1. Performans İndeksleri:
--    - coin_transactions (player_id, created_at desc): bakiye ve spin kontrolleri için.
--    - questions (category_id, is_approved): soru seçimi ve filtreler için.
--    - friends (friend_id): ters arkadaşlık ilişkisi sorguları için.
--    - rooms (status, ended_reason): lig ve oda sonuç sorguları için.
--    - rooms (host_id): ev sahibi odaları için.
--
-- 2. Kilit Sırası ve Bakiye Yarış Durumu:
--    - create_online_room: bakiye sorgusu öncesinde profiles satır kilidi (for update) alır (spend_coins ile tam uyumlu).
--    - join_room_by_code: bakiye sorgusu öncesinde profiles satır kilidi (for update) alır.
--
-- 3. Oda Tamamlanma ve XP Güvenliği:
--    - award_room_xp: status = 'finished' ve ended_reason = 'completed' şartını zorunlu kılar.
--    - finalize_weekly_league: lig skorlarına yalnız ended_reason = 'completed' olan odalar dahil edilir.
-- =====================================================================

-- 1. Performans İndeksleri
CREATE INDEX IF NOT EXISTS idx_coin_transactions_player_created
  ON public.coin_transactions (player_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_questions_category_approved
  ON public.questions (category_id, is_approved);

CREATE INDEX IF NOT EXISTS idx_friends_friend_id
  ON public.friends (friend_id);

CREATE INDEX IF NOT EXISTS idx_rooms_status_ended_reason
  ON public.rooms (status, ended_reason);

CREATE INDEX IF NOT EXISTS idx_rooms_host_id
  ON public.rooms (host_id);

-- 2. create_online_room (profil kilidi + bakiye kontrolü)
CREATE OR REPLACE FUNCTION public.create_online_room(
  p_category_name text,
  p_seconds_per_question integer,
  p_question_count integer DEFAULT 10,
  p_entry_fee integer DEFAULT 0,
  p_max_players integer DEFAULT 2
)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Kapasite: 2 = ikili özel oda, 4..50 = kalabalık oda.
  if p_max_players is null
     or p_max_players not in (2, 4, 8, 16, 30, 50) then
    raise exception 'Unsupported max players';
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
    coalesce(c.name, 'Ziman') as category_name
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
        is_custom,
        max_players,
        status
      ) values (
        v_room_code,
        v_uid,
        v_category_id,
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
        if v_attempt >= 5 then
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

revoke all on function public.create_online_room(text, integer, integer, integer, integer) from public, anon;
grant execute on function public.create_online_room(text, integer, integer, integer, integer) to authenticated, service_role;

-- 3. join_room_by_code (profil kilidi + bakiye kontrolü)
CREATE OR REPLACE FUNCTION public.join_room_by_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  perform 1 from public.profiles where id = v_uid for update;

  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and rp.left_at is null
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
    r.is_custom,
    r.max_players,
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

  -- Bakiye kontrolü kilit alındıktan sonra yapılır
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
      'max_players', v_room.max_players,
      'is_custom', v_room.is_custom,
      'category_name', v_room.category_name
    );
  end if;

  -- Kapasite kontrolü: kalabalık odada aktif oyuncu sayısı
  if v_room.is_custom and v_room.max_players > 2 then
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.left_at is null;

    if v_player_count >= v_room.max_players then
      raise exception 'Room is full';
    end if;
  else
    -- 2 kişilik oda kuralı
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id;

    if v_player_count >= 2 then
      raise exception 'Room is full';
    end if;
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  if v_room.entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -v_room.entry_fee, 'room_entry_fee');
  end if;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'entry_fee', v_room.entry_fee,
    'max_players', v_room.max_players,
    'is_custom', v_room.is_custom,
    'category_name', v_room.category_name
  );
end;
$function$;

revoke all on function public.join_room_by_code(text) from public, anon;
grant execute on function public.join_room_by_code(text) to authenticated, service_role;

-- 4. award_room_xp (status = 'finished' VE ended_reason = 'completed' zorunluluğu)
CREATE OR REPLACE FUNCTION public.award_room_xp(p_room_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_player public.room_players%rowtype;
  v_delta integer;
  v_total integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if not found then
    raise exception 'Room not found';
  end if;

  if v_room.status is distinct from 'finished'
     or coalesce(v_room.ended_reason, '') is distinct from 'completed' then
    raise exception 'Room is not completed';
  end if;

  select * into v_player
  from public.room_players
  where room_id = p_room_id
    and player_id = v_uid
  for update;
  if not found then
    raise exception 'Player is not in the room';
  end if;

  if v_player.xp_awarded then
    select coalesce(xp, 0) into v_total from public.profiles where id = v_uid;
    return coalesce(v_total, 0);
  end if;

  v_delta := least(greatest(coalesce(v_player.score, 0), 0), 2000);

  update public.room_players
  set xp_awarded = true
  where room_id = p_room_id
    and player_id = v_uid;

  if v_delta <= 0 then
    select coalesce(xp, 0) into v_total from public.profiles where id = v_uid;
    return coalesce(v_total, 0);
  end if;

  return public.award_xp_delta(v_delta);
end;
$function$;

revoke all on function public.award_room_xp(uuid) from public, anon;
grant execute on function public.award_room_xp(uuid) to authenticated, service_role;

-- 5. finalize_weekly_league (yalnız ended_reason = 'completed' odaları sayar)
CREATE OR REPLACE FUNCTION public.finalize_weekly_league(p_week date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_week date := coalesce(p_week, public.league_week_start(now() - interval '1 day'));
  v_from timestamptz := (v_week::timestamp at time zone 'Europe/Istanbul');
  v_to   timestamptz := ((v_week + 7)::timestamp at time zone 'Europe/Istanbul');
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

  -- Bu haftanın skorları (yalnız başarıyla tamamlanmış maçlar)
  create temporary table if not exists _week_scores on commit drop as
  select
    rp.player_id,
    coalesce(sum(rp.score), 0)::bigint as weekly_score
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where r.status = 'finished'
    and r.ended_reason = 'completed'
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
$function$;

revoke all on function public.finalize_weekly_league(date) from public, anon;
grant execute on function public.finalize_weekly_league(date) to authenticated, service_role;
