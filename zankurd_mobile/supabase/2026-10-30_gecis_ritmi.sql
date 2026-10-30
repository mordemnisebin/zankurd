-- T5: ortak cevap açılışı. YAZILDI, UYGULANMADI; canlıya bağlanılmadı.
-- Uygulama öncesi: pg_get_functiondef ile iki RPC'nin canlı diff'ini al;
-- begin/rollback duman testinde üyelik, erken cevap, timeout, son soru,
-- eşzamanlı expected-index ve iki kez uygulama senaryolarını doğrula.
-- Eski gövdeler kopyalanmaz. Bilinmeyen tanımda tüm işlem geri alınır.
-- Geri alma: canlı advance gövdesinde aşağıdaki yeni süre ifadesini eski
-- v_revealed_at + interval '5 seconds' ifadesine çevir; resume gövdesinde
-- yalnız eklenen current_question_reveal_ends_at çiftini kaldır. Önce
-- pg_get_functiondef/diff ve begin/rollback; sonra helper'ı drop et.
-- İstemci alan yoksa eski 5 sn'ye döner. Veri/soru içeriği değişmez.
begin;

create or replace function public.room_reveal_delay(
  p_is_custom boolean, p_max_players integer
) returns interval
language sql immutable
set search_path = public, pg_temp
as $function$
  select case when p_is_custom and p_max_players > 2
    then interval '4 seconds' else interval '3 seconds' end;
$function$;
-- Yalnız mevcut SECURITY DEFINER RPC'lerin sahibi çağırır.
revoke all on function public.room_reveal_delay(boolean, integer)
  from public, anon, authenticated;

do $patch$
declare
  v_oid regprocedure;
  v_definition text;
  v_old text := $old$v_revealed_at + interval '5 seconds'$old$;
  v_new text := 'v_revealed_at + public.room_reveal_delay(v_room.is_custom, v_room.max_players)';
  v_anchor text := $anchor$'server_now', v_server_now,$anchor$;
  v_insert text := $insert$'server_now', v_server_now,
    'current_question_reveal_ends_at', (
      select rq.revealed_at + public.room_reveal_delay(v_room.is_custom, v_room.max_players)
      from public.room_questions rq
      where rq.room_id = v_room.id
        and rq.question_index = v_room.current_question_index
    ),$insert$;
begin
  v_oid := to_regprocedure('public.advance_room_question(uuid,integer)');
  if v_oid is null then raise exception 'T5: missing advance RPC'; end if;
  v_definition := pg_get_functiondef(v_oid);
  if position(v_new in v_definition) = 0 then
    if (length(v_definition) - length(replace(v_definition, v_old, ''))) / length(v_old) <> 1
      or position('v_server_now < ' || v_old in v_definition) = 0 then
      raise exception 'T5: unexpected advance definition';
    end if;
    execute replace(v_definition, v_old, v_new);
  elsif position(v_old in v_definition) > 0 then
    raise exception 'T5: mixed advance definition';
  end if;

  v_oid := to_regprocedure('public.get_my_resumable_room()');
  if v_oid is null then raise exception 'T5: missing resume RPC'; end if;
  v_definition := pg_get_functiondef(v_oid);
  if position(v_insert in v_definition) = 0 then
    if position('current_question_reveal_ends_at' in v_definition) > 0
      or (length(v_definition) - length(replace(v_definition, v_anchor, ''))) / length(v_anchor) <> 1 then
      raise exception 'T5: unexpected resume definition';
    end if;
    execute replace(v_definition, v_anchor, v_insert);
  end if;
end;
$patch$;

alter function public.advance_room_question(uuid, integer)
  set search_path = public, pg_temp;
alter function public.get_my_resumable_room()
  set search_path = public, pg_temp;
revoke all on function public.advance_room_question(uuid, integer) from public, anon;
revoke all on function public.get_my_resumable_room() from public, anon;
grant execute on function public.advance_room_question(uuid, integer) to authenticated;
grant execute on function public.get_my_resumable_room() to authenticated;
-- Yeni tablo veya geniş istemci politikası yok; mevcut korumalar açık kalır.
alter table public.rooms enable row level security;
alter table public.room_questions enable row level security;
alter table public.room_players enable row level security;
alter table public.player_answers enable row level security;

do $verify$
declare
  v_oid regprocedure;
begin
  if public.room_reveal_delay(false, 2) <> interval '3 seconds'
    or public.room_reveal_delay(true, 2) <> interval '3 seconds'
    or public.room_reveal_delay(true, 4) <> interval '4 seconds'
    or public.room_reveal_delay(true, 50) <> interval '4 seconds' then
    raise exception 'T5: duration invariant';
  end if;
  if position('v_server_now < v_revealed_at + public.room_reveal_delay(v_room.is_custom, v_room.max_players)'
      in pg_get_functiondef('public.advance_room_question(uuid,integer)'::regprocedure)) = 0
    or position('current_question_reveal_ends_at'
      in pg_get_functiondef('public.get_my_resumable_room()'::regprocedure)) = 0 then
    raise exception 'T5: clock contract missing';
  end if;
  foreach v_oid in array array[
    'public.advance_room_question(uuid,integer)'::regprocedure,
    'public.get_my_resumable_room()'::regprocedure
  ] loop
    if has_function_privilege('anon', v_oid, 'EXECUTE')
      or not has_function_privilege('authenticated', v_oid, 'EXECUTE')
      or not exists (
        select 1 from pg_proc where oid = v_oid and prosecdef
          and 'search_path=public, pg_temp' = any(proconfig)
      ) then
      raise exception 'T5: RPC security invariant';
    end if;
  end loop;
  if has_function_privilege('anon', 'public.room_reveal_delay(boolean,integer)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.room_reveal_delay(boolean,integer)', 'EXECUTE') then
    raise exception 'T5: internal helper exposed';
  end if;
  if exists (
    select 1 from pg_class where oid = any(array[
      'public.rooms'::regclass, 'public.room_questions'::regclass,
      'public.room_players'::regclass, 'public.player_answers'::regclass
    ]) and not relrowsecurity
  ) then raise exception 'T5: RLS disabled'; end if;
end;
$verify$;
commit;
