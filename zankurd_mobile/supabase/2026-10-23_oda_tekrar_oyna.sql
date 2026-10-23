-- Özel odada "Tekrar oyna" (2026-10-23).
--
-- Niçin: kullanıcı geri bildirimi — oda bitince aynı kişilerle yeniden
-- oynamak için her şey sıfırdan kuruluyordu (oda kur, kodu yeniden paylaş,
-- herkes yeniden girsin). 2.1.0'ın ilk gecesi 7 odanın 3'ü dolu oynanmıştı.
--
-- Ne yapar: bitmiş bir ÖZEL odanın (is_custom) oyuncusu create_room_rematch
-- çağırınca aynı ayarlarla (kategori, soru sayısı, süre, giriş ücreti,
-- kapasite) yeni bir lobi kurulur ve eski odanın rematch_room_id alanına
-- yazılır. Aynı odadan sonra basanlar YENİ oda kurmaz, o lobiye katılır.
-- Kurma ve katılma mevcut create_online_room_impl / join_room_by_code ile
-- yapılır: jeton, kapasite, engel ve çıkarılma kuralları aynen geçerlidir.
-- Eski oda satırı kilitlenir; iki kişi aynı anda bassa da tek lobi açılır.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-23_oda_tekrar_oyna.sql

begin;

alter table public.rooms
  add column if not exists rematch_room_id uuid
  references public.rooms(id) on delete set null;

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

commit;
