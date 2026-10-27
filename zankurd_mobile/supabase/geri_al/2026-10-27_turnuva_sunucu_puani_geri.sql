-- Geri alma: 2026-10-27_turnuva_sunucu_puani.sql
-- submit_tournament_match eski gövdesine döner (istemci skoru her kupada
-- yazılır), yeni kupalar yeniden ödülsüz açılır, maç soru/cevap tabloları
-- ve üç RPC kaldırılır. advance_tournament (kupa kilidi),
-- get_tournament_bracket (serverScored) ve claim_tournament_reward (oynamış
-- olma şartı) yeni gövdelerinde kalabilir: eski davranışla uyumludur. Eski gövde: canlıdan alınan
-- 2026-07-31_tournament_score_authority.sql sonrası tanım (aşağıda).
begin;

drop function if exists public.answer_tournament_question(uuid, integer, text);
drop function if exists public.present_tournament_question(uuid, integer);
drop function if exists public.start_tournament_match(uuid);
drop table if exists public.tournament_match_question_starts;
drop table if exists public.tournament_match_answers;
drop table if exists public.tournament_match_questions;
alter table public.tournaments
  alter column scores_server_validated set default false;

create or replace function public.submit_tournament_match(p_match_id uuid, p_score integer)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
  v_match public.tournament_matches;
  v_winner uuid;
  v_score int := greatest(coalesce(p_score, 0), 0);
  v_max_score int;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;
  select * into v_match from public.tournament_matches
   where id = p_match_id for update;
  if not found then
    raise exception 'Match not found';
  end if;
  if v_user not in (coalesce(v_match.player_one, '00000000-0000-0000-0000-000000000000'::uuid),
                    coalesce(v_match.player_two, '00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'Player is not in this match';
  end if;
  if v_match.status = 'completed' then
    return jsonb_build_object('status', 'completed', 'winner_id', v_match.winner_id);
  end if;
  select coalesce(t.questions_per_match, 4) * 150 into v_max_score
    from public.tournaments t where t.id = v_match.tournament_id;
  v_score := least(v_score, coalesce(v_max_score, 600));
  if v_user = v_match.player_one and v_match.submitted_one is null then
    update public.tournament_matches set score_one = v_score, submitted_one = now() where id = p_match_id;
  elsif v_user = v_match.player_two and v_match.submitted_two is null then
    update public.tournament_matches set score_two = v_score, submitted_two = now() where id = p_match_id;
  end if;
  select * into v_match from public.tournament_matches where id = p_match_id;
  if v_match.submitted_one is not null and v_match.submitted_two is not null then
    if coalesce(v_match.score_one, 0) > coalesce(v_match.score_two, 0) then
      v_winner := v_match.player_one;
    elsif coalesce(v_match.score_two, 0) > coalesce(v_match.score_one, 0) then
      v_winner := v_match.player_two;
    elsif v_match.submitted_one <= v_match.submitted_two then
      v_winner := v_match.player_one;
    else
      v_winner := v_match.player_two;
    end if;
    update public.tournament_matches set status = 'completed', winner_id = v_winner where id = p_match_id;
    perform public.advance_tournament(v_match.tournament_id);
  end if;
  select * into v_match from public.tournament_matches where id = p_match_id;
  return jsonb_build_object('status', v_match.status, 'winner_id', v_match.winner_id);
end;
$function$;

commit;
