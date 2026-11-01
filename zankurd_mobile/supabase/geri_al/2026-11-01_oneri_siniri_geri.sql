-- Geri alma: 2026-11-01_oneri_siniri.sql
begin;

drop trigger if exists suggested_questions_rate_limit
  on public.suggested_questions;
drop function if exists public.limit_suggested_question_rate();

commit;
