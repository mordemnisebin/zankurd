-- T10: süre dolumu cevap değildir. YAZILDI, UYGULANMADI.
-- Canlı DB'ye bağlanılmadı. Uygulamadan önce canlı pg_get_functiondef diff'i,
-- ardından begin/rollback içinde 0/4 timeout, 2 cevap+2 timeout, ayrılan üye,
-- yetkisiz erişim ve ikinci uygulama duman testi zorunludur.
-- Eski RPC gövdesi kopyalanmaz; beklenmeyen canlı tanımda işlem durur.
-- Geri alma: yalnız aşağıdaki v_new parçasını canlı gövdede v_old'a çevir;
-- ayrıca v_phase_new -> v_phase_old; önce canlı diff ve begin/rollback.
-- Oyun/puan/advance kuralları değişmez.
begin;
do $patch$
declare
  v_oid regprocedure := to_regprocedure('public.get_room_answer_progress(uuid)');
  v_definition text;
  v_old text := 'and pa.question_id = v_question_id;';
  v_new text := $new$and pa.question_id = v_question_id
      and pa.selected_option in ('A', 'B', 'C', 'D');$new$;
  v_phase_old text := $old$'active', v_active$old$;
  v_phase_new text := $new$'active', v_active,
    'revealed', exists (
      select 1 from public.room_questions rq
      where rq.room_id = p_room_id and rq.question_index = v_index
        and rq.revealed_at is not null
    )$new$;
begin
  if v_oid is null then raise exception 'T10: missing answer progress RPC'; end if;
  v_definition := pg_get_functiondef(v_oid);
  if not exists (select 1 from pg_proc where oid = v_oid and prosecdef)
    or position('auth.uid()' in v_definition) = 0
    or position('public.is_room_participant(p_room_id)' in v_definition) = 0
    or position('rp.left_at is null' in v_definition) = 0 then
    raise exception 'T10: unexpected progress security definition';
  end if;
  if position(v_new in v_definition) = 0 then
    if (length(v_definition) - length(replace(v_definition, v_old, ''))) / length(v_old) <> 1 then
      raise exception 'T10: unexpected answer count definition';
    end if;
    execute replace(v_definition, v_old, v_new);
  elsif position(v_old in v_definition) > 0 then
    raise exception 'T10: mixed answer count definition';
  end if;
  v_definition := pg_get_functiondef(v_oid);
  if position(v_phase_new in v_definition) = 0 then
    if position($key$'revealed'$key$ in v_definition) > 0
      or (length(v_definition) - length(replace(v_definition, v_phase_old, ''))) / length(v_phase_old) <> 1 then
      raise exception 'T10: unexpected progress phase definition';
    end if;
    execute replace(v_definition, v_phase_old, v_phase_new);
  end if;
end;
$patch$;
alter function public.get_room_answer_progress(uuid) set search_path = public, pg_temp;
revoke all on function public.get_room_answer_progress(uuid) from public, anon;
grant execute on function public.get_room_answer_progress(uuid) to authenticated, service_role;
do $verify$
begin
  if position($filter$pa.selected_option in ('A', 'B', 'C', 'D')$filter$
    in pg_get_functiondef('public.get_room_answer_progress(uuid)'::regprocedure)) = 0
    or position($key$'revealed'$key$
      in pg_get_functiondef('public.get_room_answer_progress(uuid)'::regprocedure)) = 0
    or has_function_privilege('anon', 'public.get_room_answer_progress(uuid)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.get_room_answer_progress(uuid)', 'EXECUTE') then
    raise exception 'T10: answer count invariant failed';
  end if;
end;
$verify$;
commit;
