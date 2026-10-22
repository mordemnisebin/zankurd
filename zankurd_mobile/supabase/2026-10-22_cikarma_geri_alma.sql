-- 2026-10-22: odadan çıkarmayı geri alma.
--
-- Eksik: oda sahibi yanlışlıkla çıkardığı birini aynı odaya geri alamıyordu
-- (room_kicks kalıcıydı; yeni oda kurmak gerekiyordu).
--
-- invite_friends_to_room: sahip çıkarılanı davet edince room_kicks satırı
-- silinir; davetli kabul edip ya da kodla geri girebilir. Sahip olmayan
-- üye çıkarılanı davet edemez (davet sessizce atlanır).

CREATE OR REPLACE FUNCTION public.invite_friends_to_room(p_room_id uuid, p_friend_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_ids uuid[];
  v_friend uuid;
  v_count integer := 0;
  v_active integer;
  v_cap integer;
  v_recent integer;
  v_name text;
  v_prev timestamptz;
  v_push boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_room_id is null or p_friend_ids is null
     or coalesce(array_length(p_friend_ids, 1), 0) = 0 then
    return 0;
  end if;

  -- Yinelenenleri ve null'ları at; çağrı başına en çok 20 kişi.
  select coalesce(array_agg(distinct x), '{}') into v_ids
  from unnest(p_friend_ids) as x
  where x is not null and x <> v_uid;
  if coalesce(array_length(v_ids, 1), 0) > 20 then
    raise exception 'Too many invitees';
  end if;

  select r.id, r.status, r.is_custom, r.max_players, r.host_id into v_room
  from public.rooms r
  where r.id = p_room_id
  for share;

  -- Odayı kuran ya da odada AKTİF olan her oyuncu davet edebilir; lobi
  -- dışında (başladı/bitti) davet anlamsız.
  if not found
     or v_room.status <> 'lobby'
     or not exists (
       select 1 from public.room_players rp
       where rp.room_id = p_room_id
         and rp.player_id = v_uid
         and rp.left_at is null
     ) then
    raise exception 'Room not found or already started';
  end if;

  select count(*)::integer into v_active
  from public.room_players rp
  where rp.room_id = p_room_id and rp.left_at is null;

  -- Sınır önce ayrı hesaplanır: PL/pgSQL `IF` koşulunu ilk THEN'de
  -- keser; koşul içindeki `CASE … THEN` göçü sözdizimi hatasıyla
  -- düşürüyordu (canlıda rollback'li duman testi, 2026-10-18).
  v_cap := case
    when v_room.is_custom and v_room.max_players > 2 then v_room.max_players
    else 2
  end;
  if v_active >= v_cap then
    raise exception 'Room is full';
  end if;

  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).
  select count(*)::integer into v_recent
  from public.room_invites i
  where i.inviter_id = v_uid
    and i.created_at > now() - interval '1 hour';
  if v_recent + array_length(v_ids, 1) > 100 then
    raise exception 'Too many invites';
  end if;

  select coalesce(nullif(btrim(left(p.display_name, 40)), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = v_uid;
  v_name := coalesce(v_name, 'ZanKurd');

  foreach v_friend in array v_ids loop
    -- Kabul edilmiş arkadaş, iki yönde engelsiz, odada değil. Aksi halde
    -- sessizce atlanır (engel ifşa edilmez; dönen sayı gerçek davetleri söyler).
    if not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = v_friend
       )
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = v_friend)
            or (b.blocker_id = v_friend and b.blocked_id = v_uid)
       )
       -- Davetli ile oda SAHİBİ arasında (her iki yönde) engel varsa da
       -- atlanır: katılımda zaten reddedilirdi, ölü davet kartı üretme.
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_room.host_id and b.blocked_id = v_friend)
            or (b.blocker_id = v_friend and b.blocked_id = v_room.host_id)
       )
       or exists (
         select 1 from public.room_players rp
         where rp.room_id = p_room_id
           and rp.player_id = v_friend
           and rp.left_at is null
       )
       -- Odadan çıkarılanı yalnız oda SAHİBİ yeniden davet edebilir
       -- (2026-10-22); başka üyenin daveti katılımda reddedilirdi.
       or (v_uid is distinct from v_room.host_id and exists (
         select 1 from public.room_kicks k
         where k.room_id = p_room_id
           and k.player_id = v_friend
       )) then
      continue;
    end if;

    -- Sahibin daveti çıkarmayı geri alır: yanlışlıkla çıkarılan aynı odaya
    -- daveti kabul ederek ya da kodla dönebilir.
    if v_uid = v_room.host_id then
      delete from public.room_kicks k
      where k.room_id = p_room_id
        and k.player_id = v_friend;
    end if;

    -- Bildirim yalnız yeni ya da 2 dakikadan eski davette kuyruklanır:
    -- yeniden dokunuş telefonu titretip durmasın.
    select i.created_at into v_prev
    from public.room_invites i
    where i.room_id = p_room_id and i.invitee_id = v_friend;
    v_push := v_prev is null or v_prev < now() - interval '2 minutes';

    insert into public.room_invites (room_id, inviter_id, invitee_id)
    values (p_room_id, v_uid, v_friend)
    on conflict (room_id, invitee_id) do update
      set inviter_id = excluded.inviter_id,
          status = 'pending',
          created_at = now();

    if v_push then
      insert into public.push_outbox (to_user_id, kind, title, body)
      values (
        v_friend,
        'room_invite',
        'ZanKurd',
        -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli
        -- (enqueue_async_duel_invite_push ile aynı kalıp).
        v_name || ' te vedixwîne odeyê · ' || v_name
          || ' seni odaya davet etti'
      );
    end if;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;
