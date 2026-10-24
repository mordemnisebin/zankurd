-- join_room_by_code: engelleme denetimi geri (2026-10-17).
-- 2026-10-16_indeks_ve_kilit_sertlestirme.sql fonksiyonu yeniden yazarken
-- 2026-10-02 M5 engelleme bloğunu düşürmüştü: engellenen oyuncu, kendisini
-- engelleyenin (ya da odadaki birinin) odasına kodla girebiliyordu. Gövde
-- CANLI tanımdan alındı; yalnız engel bloğu oyuncu sayımından önce geri
-- kondu. Profil satır kilidi (çift harcama koruması) korunur.
begin;
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

  -- Engelleme (2026-10-02 M5): oda sahibi ya da odadaki biriyle aramızda
  -- HER İKİ YÖNDE engel varsa katılım reddedilir. Mesaj bilerek mevcut
  -- "bulunamadı" mesajıdır: engelleyen kişinin odasını arayan bir kullanıcı
  -- engellendiğini öğrenmemeli; istemci bunu zaten `notFound`a eşler.
  if exists (
    select 1
    from public.blocked_users b
    where (b.blocker_id = v_uid
           and (b.blocked_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocked_id)))
       or (b.blocked_id = v_uid
           and (b.blocker_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocker_id)))
  ) then
    raise exception 'Room not found or already started';
  end if;
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

commit;
