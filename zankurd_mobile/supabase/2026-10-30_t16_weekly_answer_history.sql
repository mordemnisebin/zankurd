-- T16 Ö2: profil toplamıyla aynı cevap kaynaklarının günlük dağılımı.
-- YENİ RPC; mevcut fonksiyon gövdeleri değiştirilmez. Canlıya uygulanmadı.
-- İstemci yerel takvimdeki sekiz gece yarısını UTC olarak gönderir; böylece
-- 23/25 saatlik günler de yerel MistakeStore günleriyle tam eşleşir.
begin;

create function public.get_my_online_answer_history(p_day_boundaries timestamptz[])
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_history jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_day_boundaries is null
    or array_ndims(p_day_boundaries) <> 1
    or array_lower(p_day_boundaries, 1) <> 1
    or cardinality(p_day_boundaries) <> 8
    or exists (
      select 1 from unnest(p_day_boundaries) boundary
      where boundary is null or not isfinite(boundary)
    )
    or exists (
      select 1 from generate_series(1, 7) i
      where p_day_boundaries[i + 1] - p_day_boundaries[i]
        not between interval '20 hours' and interval '28 hours'
    ) then
    raise exception 'Expected eight consecutive calendar day boundaries';
  end if;

  with own_answers as (
    select pa.is_correct, pa.created_at as answered_at
    from public.player_answers pa
    where pa.player_id = v_uid
      and pa.selected_option in ('A', 'B', 'C', 'D')
      and pa.created_at >= p_day_boundaries[1]
      and pa.created_at < p_day_boundaries[8]
      and exists (
        select 1
        from public.room_questions rq
        join public.rooms r on r.id = rq.room_id
        where rq.room_id = pa.room_id
          and rq.question_id = pa.question_id
          and (
            rq.revealed_at is not null
            or rq.question_index < r.current_question_index
          )
      )
    union all
    select da.is_correct, da.answered_at
    from public.async_duel_answers da
    where da.player_id = v_uid
      and da.choice in ('A', 'B', 'C', 'D')
      and da.answered_at >= p_day_boundaries[1]
      and da.answered_at < p_day_boundaries[8]
    union all
    select ta.is_correct, ta.answered_at
    from public.tournament_match_answers ta
    where ta.player_id = v_uid
      and ta.choice in ('A', 'B', 'C', 'D')
      and ta.answered_at >= p_day_boundaries[1]
      and ta.answered_at < p_day_boundaries[8]
  ), daily as (
    select d.day_index,
      count(*) filter (where a.is_correct) as correct,
      count(*) filter (where not a.is_correct) as wrong
    from generate_series(1, 7) d(day_index)
    left join own_answers a
      on a.answered_at >= p_day_boundaries[d.day_index]
      and a.answered_at < p_day_boundaries[d.day_index + 1]
    group by d.day_index
  )
  select jsonb_agg(
    jsonb_build_object('correct', correct, 'wrong', wrong) order by day_index
  ) into v_history
  from daily;

  return v_history;
end;
$function$;

revoke all on function public.get_my_online_answer_history(timestamptz[]) from public, anon;
grant execute on function public.get_my_online_answer_history(timestamptz[]) to authenticated;

commit;
