-- Yalnız açık operasyon onayıyla uygulanır. Eski BEYAN açığını geri getirir.
-- Oturum/cevap/sonuç verileri inceleme için korunur; yeni RPC'ler kapatılır.
begin;
do $rollback$
declare v_backup record; v_acl jsonb; v_signature text;
begin
  for v_backup in select * from public.g5g9_function_backup loop
    execute v_backup.definition;
    execute 'revoke all on function ' || v_backup.signature || ' from public, anon, authenticated';
    for v_acl in select * from jsonb_array_elements(v_backup.privileges) loop
      execute 'grant execute on function ' || v_backup.signature || ' to ' ||
        case when v_acl->>'role' = 'PUBLIC' then 'PUBLIC' else quote_ident(v_acl->>'role') end ||
        case when (v_acl->>'grantable')::boolean then ' with grant option' else '' end;
    end loop;
  end loop;
  foreach v_signature in array array[
    'get_verified_daily_question_ids()', 'prepare_verified_solo_questions(text,integer)', 'start_verified_quiz(uuid,uuid[],boolean,uuid)',
    'answer_verified_quiz(uuid,uuid,text)', 'claim_verified_solo_reward(uuid)',
    'submit_verified_daily_event_result(uuid)', 'get_verified_daily_event_board()'
  ] loop
    if to_regprocedure('public.' || v_signature) is not null then
      execute 'revoke all on function public.' || v_signature || ' from public, anon, authenticated';
    end if;
  end loop;
end;
$rollback$;
commit;
