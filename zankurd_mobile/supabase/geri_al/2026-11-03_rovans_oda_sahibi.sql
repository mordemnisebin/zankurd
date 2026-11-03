-- GERI ALMA: 2026-11-03_rovans_oda_sahibi.sql
-- create_room_rematch'i 2026-10-23_oda_tekrar_oyna.sql, leave_room'u
-- 2026-10-24_sunucu_sertlestirme.sql govdesine dondurur; yeni RPC'leri ve
-- yardimciyi siler. Yeni kolonlar (rooms.rematch_owner_id,
-- room_players.last_seen_at) veri kaybi olmasin diye KALIR (zararsiz, NULL).
begin;

drop function if exists public.update_room_settings(uuid, text[], integer, integer);
drop function if exists public.room_heartbeat(uuid);
drop function if exists public.room_lobby_state_json(uuid);

create or replace function public.create_room_rematch(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_next record;
  v_names text[];
  v_result json;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.status <> 'finished' or not v_room.is_custom then
    raise exception 'Rematch not available';
  end if;

  if not exists (
    select 1 from public.room_players rp
    where rp.room_id = p_room_id and rp.player_id = v_uid
  ) then
    raise exception 'Rematch not available';
  end if;

  -- Biri yeni lobiyi zaten kurduysa ona katıl.
  if v_room.rematch_room_id is not null then
    select r.id, r.code, r.status into v_next
    from public.rooms r
    where r.id = v_room.rematch_room_id;
    if found and v_next.status = 'lobby' then
      return public.join_room_by_code(v_next.code);
    end if;
  end if;

  if v_room.category_ids is not null and cardinality(v_room.category_ids) > 0 then
    select array_agg(c.name order by c.name) into v_names
    from public.categories c
    where c.id = any(v_room.category_ids);
  elsif v_room.category_id is not null then
    select array[c.name] into v_names
    from public.categories c
    where c.id = v_room.category_id;
  else
    v_names := null; -- Karışık
  end if;

  v_result := public.create_online_room_impl(
    v_names,
    coalesce(v_room.seconds_per_question, 20),
    v_room.question_count,
    coalesce(v_room.entry_fee, 0),
    coalesce(v_room.max_players, 2),
    false
  );

  update public.rooms
  set rematch_room_id = (v_result ->> 'room_id')::uuid
  where id = p_room_id;

  return v_result;
end;
$function$;

revoke all on function public.create_room_rematch(uuid) from public, anon;
grant execute on function public.create_room_rematch(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.leave_room(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_final_revealed boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  -- Tekrarlanan çıkış terminal maçın tarihsel üyeliğini değiştirmez.
  if v_room.status not in ('lobby', 'active') then
    return json_build_object(
      'status', v_room.status,
      'reason', coalesce(v_room.ended_reason, 'already_finished'),
      'forfeited_by', v_room.forfeited_by
    );
  end if;

  -- Lobiden biri ayrılınca lobi etkinliği yenilenir: misafirin room_players
  -- satırı silindiğinden joined_at kaybolur, bayat-lobi süzgeci (30 dk)
  -- bu zaman damgasına bakar. Kalabalık odayı da kapsar (aşağıdaki
  -- ortak yardımcıdan ÖNCE yazılır).
  if v_room.status = 'lobby' then
    update public.rooms r
    set last_activity_at = now()
    where r.id = p_room_id;
  end if;

  -- Kalabalık oda (is_custom ve max_players > 2): ayrılma mantığı ortak
  -- yardımcıda (lobide host devri, oyunda left_at, aktif < 2 ise erken bitiş).
  -- Aşağıdaki eski 2 kişilik yol DEĞİŞMEDEN kalır (yalnız iade çağrıları eklendi).
  if v_room.is_custom and v_room.max_players > 2 then
    return public.crowd_room_member_leave(p_room_id, v_uid);
  end if;

  update public.room_players rp
  set is_ready = false
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if v_room.status = 'active' then
    -- Son soru açıklandıktan sonra (bütün sorular bitti) çıkış maçı
    -- terketme sayılmaz: skorlar kesinleşti, kazanan 'completed' odanın XP,
    -- jeton ve lig puanını alır. crowd_room_member_leave ile aynı koruma;
    -- kaybeden son anda çıkıp kazananın ödülünü engelleyemez. İade YOK
    -- (havuz ödül talebiyle dağıtılır; ayrılan havuza katılmaz).
    select count(*) = v_room.question_count
           and bool_and(rq.revealed_at is not null)
    into v_final_revealed
    from public.room_questions rq
    where rq.room_id = p_room_id;
    v_final_revealed := coalesce(v_final_revealed, false);

    if v_final_revealed then
      update public.rooms r
      set
        status = 'finished',
        current_question_index = r.question_count,
        finished_at = coalesce(r.finished_at, now()),
        ended_reason = 'completed',
        forfeited_by = null
      where r.id = p_room_id;

      delete from public.matchmaking_queue mq
      where mq.room_id = p_room_id;

      return json_build_object(
        'status', 'finished',
        'reason', 'completed',
        'forfeited_by', null
      );
    end if;

    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'forfeit',
      forfeited_by = v_uid
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    -- Ayrılan kaybeder; haksız yere oyunsuz kalan rakibin giriş ücreti iade.
    perform public.refund_room_entry_fees(p_room_id, v_uid);

    return json_build_object(
      'status', 'finished',
      'reason', 'forfeit',
      'forfeited_by', v_uid
    );
  end if;

  if v_room.status = 'lobby' and v_room.host_id = v_uid then
    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'host_left',
      forfeited_by = null
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    perform public.refund_room_entry_fees(p_room_id, null);

    return json_build_object(
      'status', 'finished',
      'reason', 'host_left',
      'forfeited_by', null
    );
  end if;

  if v_room.status = 'lobby' then
    -- Lobiden çıkan misafir kendi giriş ücretini geri alır (satır silinmeden önce).
    perform public.refund_room_entry_fee(p_room_id, v_uid);

    delete from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = v_uid;
    return json_build_object(
      'status', 'left',
      'reason', 'guest_left',
      'forfeited_by', null
    );
  end if;

  return json_build_object(
    'status', v_room.status,
    'reason', coalesce(v_room.ended_reason, 'already_finished'),
    'forfeited_by', v_room.forfeited_by
  );
end;
$function$;

revoke all on function public.leave_room(uuid) from public, anon;
grant execute on function public.leave_room(uuid) to authenticated;

commit;
