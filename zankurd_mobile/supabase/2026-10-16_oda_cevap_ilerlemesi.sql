-- Kalabalık odada "x/N cevapladı" sayacı. İstemci player_answers'ı okuyamaz
-- (cevaplar soru açıklanana dek gizli), oda yükünde de sayı yoktu; ekran
-- yalnız "Diğer oyuncular bekleniyor" diyebiliyordu. Bu fonksiyon yalnız
-- SAYI döndürür, kimin ne cevapladığını sızdırmaz; çağıran odanın üyesi
-- olmalıdır.
begin;

create or replace function public.get_room_answer_progress(p_room_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_index integer;
  v_question_id uuid;
  v_answered integer := 0;
  v_active integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_room_participant(p_room_id) then
    raise exception 'Player is not in the room';
  end if;

  select r.current_question_index into v_index
  from public.rooms r
  where r.id = p_room_id;

  select rq.question_id into v_question_id
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_index = v_index;

  select count(*)::integer into v_active
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.left_at is null;

  if v_question_id is not null then
    select count(*)::integer into v_answered
    from public.player_answers pa
    join public.room_players rp
      on rp.room_id = pa.room_id
     and rp.player_id = pa.player_id
     and rp.left_at is null
    where pa.room_id = p_room_id
      and pa.question_id = v_question_id;
  end if;

  return json_build_object(
    'question_index', v_index,
    'answered', v_answered,
    'active', v_active
  );
end;
$function$;

revoke all on function public.get_room_answer_progress(uuid) from public, anon;
grant execute on function public.get_room_answer_progress(uuid) to authenticated, service_role;

commit;
