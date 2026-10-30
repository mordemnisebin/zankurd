-- T11: Profil istatistiğine oda/canlı düello, sırayla düello ve turnuvada
-- verilmiş gerçek cevapları ekler. Tek oyunculu/günlük/pratik kayıtları
-- istemcinin yerel istatistiğinde kalır; burada tekrar sayılmaz.
-- Yeni RPC: mevcut sunucu fonksiyonlarının gövdelerini değiştirmez.
-- Canlıya uygulanmadı. Kimliği doğrulanmış misafir de auth.uid() ile okunur.
begin;

create or replace function public.get_my_online_answer_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_stats jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  with own_answers as (
    select pa.is_correct
    from public.player_answers pa
    where pa.player_id = v_uid
      and pa.selected_option in ('A', 'B', 'C', 'D')
      -- Aktif sorunun gizli doğruluğunu toplam üzerinden de sızdırma.
      -- Geçmiş indeks kapısı, reveal zamanı olmayan eski kayıtlarla uyumlu.
      -- EXISTS aynı yanıtın birden çok soru eşleşmesiyle çoğalmasını önler.
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
    select da.is_correct
    from public.async_duel_answers da
    where da.player_id = v_uid
      and da.choice in ('A', 'B', 'C', 'D')
    union all
    select ta.is_correct
    from public.tournament_match_answers ta
    where ta.player_id = v_uid
      and ta.choice in ('A', 'B', 'C', 'D')
    -- Bu iki modda kendi doğruluğu cevap gönderme RPC'sinde zaten açıklanır.
    -- TIMEOUT gerçek cevap olmadığı için hiçbir modda paydada yer almaz.
  )
  select jsonb_build_object(
    'correct', count(*) filter (where is_correct),
    'wrong', count(*) filter (where not is_correct)
  ) into v_stats
  from own_answers;

  return v_stats;
end;
$function$;

revoke all on function public.get_my_online_answer_stats() from public, anon;
grant execute on function public.get_my_online_answer_stats() to authenticated;

commit;
