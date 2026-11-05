-- GERİ ALMA: 2026-11-16_rekabet_sunum.sql
-- Göç yalnız yeni nesne yarattığı için geri alma yalnız onları kaldırır; mevcut işlevler
-- (get_verified_daily_question_ids, start/answer_verified_quiz, submit_verified_daily_event_result,
-- get_room_questions, düello sarmalayıcıları) hiç değişmediğinden geri yüklenecek gövde yoktur.
-- Yeni istemci bu işlevler yokken (PGRST202) eski yola düşer; geri alma güvenlidir.
-- UYARI: verified_quiz_presentations satırları silinir (yalnız yeni yolun sunum zamanları).
-- Yeni yolla başlamış günlük oturumlar (verified_quiz_sessions) KALIR; eski yol onları
-- kendi tur kimliğiyle sürdürmez (istemci yeni tur kimliği üretir, günlük hak yanmış sayılır).
begin;

drop function if exists public.start_verified_daily_v2();
drop function if exists public.present_verified_daily_question(uuid, integer);
drop function if exists public.answer_verified_daily_question(uuid, integer, text);
drop function if exists public.submit_verified_daily_event_result_v2(uuid);
drop function if exists public.get_room_questions_v2(uuid);
drop function if exists public.start_async_duel_masked(text, uuid);
drop function if exists public.create_async_duel_challenge_masked(text, uuid, uuid);
drop function if exists public.accept_async_duel_challenge_masked(text);
drop function if exists public.resume_my_async_duel_masked(uuid);
drop function if exists public._w2_mask_duel_payload(jsonb);
drop function if exists public._w2_daily_state(public.verified_quiz_sessions);
drop function if exists public._w2_daily_set(date);
drop function if exists public._w2_opaque_id(text, integer);
drop table if exists public.verified_quiz_presentations;

do $w2_geri$
begin
  if to_regprocedure('public.start_verified_daily_v2()') is not null
     or to_regprocedure('public.get_room_questions_v2(uuid)') is not null
     or to_regprocedure('public.start_async_duel_masked(text,uuid)') is not null
     or to_regclass('public.verified_quiz_presentations') is not null then
    raise exception 'w2 geri: yeni nesneler kaldırılamadı';
  end if;
  if to_regprocedure('public.get_room_questions(uuid)') is null
     or to_regprocedure('public.start_verified_quiz(uuid,uuid[],boolean,uuid)') is null
     or to_regprocedure('public.start_async_duel(text)') is null then
    raise exception 'w2 geri: mevcut işlevler bulunamadı';
  end if;
end
$w2_geri$;

commit;
