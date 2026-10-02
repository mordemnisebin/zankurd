-- 2026-09-06: oda XP'si sunucu skorundan yazılır.
--
-- İstemci oda turunda kendi hesapladığı delta ile award_xp_delta
-- çağırıyordu. Bu fonksiyon oda üyeliğini ve bitiş durumunu doğrular,
-- room_players.score tavanını uygular, aynı oda için bir kez yazar.
-- Solo award_xp_delta durur. Idempotent.

alter table public.room_players
  add column if not exists xp_awarded boolean not null default false;

create or replace function public.award_room_xp(p_room_id uuid)
returns integer
language plpgsql
volatile
security definer
set search_path = public
as $$
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
  if v_room.status is distinct from 'finished' then
    raise exception 'Room is not finished';
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
$$;

revoke all on function public.award_room_xp(uuid) from public, anon;
grant execute on function public.award_room_xp(uuid) to authenticated;
grant execute on function public.award_room_xp(uuid) to service_role;
