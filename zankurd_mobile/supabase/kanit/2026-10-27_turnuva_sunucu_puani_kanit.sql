-- Kanıt: 2026-10-27_turnuva_sunucu_puani.sql (begin…rollback içinde koşar).
-- İki gerçek test oyuncusuyla yeni bir 2 kişilik kupa kurulur; maç sunucuda
-- oynanır; içerik gizliliği, süre, skor, kazanan, kupa bitişi ve şampiyon
-- ödülü denetlenir. Her denetim KANIT_OK ya da KANIT_HATA satırı üretir.
create temp table if not exists _kanit (n serial, line text);
do $$
declare
  a uuid; b uuid;
  t uuid; m uuid;
  r jsonb; s jsonb; p jsonb;
  i int;
  correct text;
  v_score_a int; v_score_b int;
  k text;
begin
  select e.player_id into a from public.tournament_entries e
   where e.display_name = 'Test Ajan 4' order by e.joined_at desc limit 1;
  select e.player_id into b from public.tournament_entries e
   where e.display_name = 'Rojd' order by e.joined_at desc limit 1;

  insert into public.tournaments (size, min_size, status, started_at)
  values (2, 2, 'running', now()) returning id into t;
  k := case when (select scores_server_validated from public.tournaments where id = t)
            then 'KANIT_OK 1 yeni kupa sunucu puanlı'
            else 'KANIT_HATA 1 yeni kupa sunucu puanlı değil' end;
  insert into pg_temp._kanit(line) values (k);

  insert into public.tournament_entries (tournament_id, player_id, display_name)
  values (t, a, 'Test Ajan 4'), (t, b, 'Rojd');
  insert into public.tournament_matches (tournament_id, round, slot, player_one, player_two, deadline)
  values (t, 1, 0, a, b, now() + interval '24 hours') returning id into m;

  -- A başlatır: 4 soru, hiçbirinin içeriği yok (sunulmadı), doğru şık yok.
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  r := public.start_tournament_match(m);
  k := case when jsonb_array_length(r->'questions') = 4
             and r->>'role' = 'creator' and r->>'opponent_name' = 'Rojd'
             and r->'questions'->0->>'prompt' = ''
             and r->'questions'->3->>'prompt' = ''
             and not ((r->'questions'->0) ? 'correct_option')
            then 'KANIT_OK 2 başlatma: 4 yer tutucu, içerik ve doğru şık yok'
            else format('KANIT_HATA 2 %s', r) end;
  insert into pg_temp._kanit(line) values (k);

  -- Sunulmamış soruya cevap reddedilir.
  begin
    perform public.answer_tournament_question(m, 0, 'A');
    insert into pg_temp._kanit(line) values ('KANIT_HATA 3 sunumsuz cevap kabul edildi');
  exception when others then
    insert into pg_temp._kanit(line) values (
      case when sqlerrm = 'Not presented' then 'KANIT_OK 3 sunumsuz cevap reddedildi'
           else format('KANIT_HATA 3 %s', sqlerrm) end);
  end;

  -- Sunum içeriği verir (doğru şık yok); atlamalı sunum reddedilir.
  p := public.present_tournament_question(m, 0);
  k := case when coalesce(p->'question'->>'prompt', '') <> ''
             and (p->'question'->>'index')::int = 0
             and not ((p->'question') ? 'correct_option')
            then 'KANIT_OK 4 sunum içeriği verir, doğru şıkkı vermez'
            else format('KANIT_HATA 4 %s', p) end;
  insert into pg_temp._kanit(line) values (k);
  begin
    perform public.present_tournament_question(m, 2);
    insert into pg_temp._kanit(line) values ('KANIT_HATA 5 atlamalı sunum kabul edildi');
  exception when others then
    insert into pg_temp._kanit(line) values (
      case when sqlerrm = 'Invalid index' then 'KANIT_OK 5 atlamalı sunum reddedildi'
           else format('KANIT_HATA 5 %s', sqlerrm) end);
  end;

  -- A dört soruyu doğru cevaplar.
  for i in 0..3 loop
    if i > 0 then perform public.present_tournament_question(m, i); end if;
    select q.correct_option into correct from public.questions q
     where q.id = (select question_ids[i + 1] from public.tournament_match_questions where match_id = m);
    s := public.answer_tournament_question(m, i, correct);
  end loop;
  k := case when (s->>'finished')::boolean and s->'result'->>'status' = 'waiting'
             and (s->'result'->>'my_correct')::int = 4
             and (s->'result'->>'my_score')::int between 400 and 600
            then format('KANIT_OK 6 A bitti: 4 doğru, puan %s, rakip bekleniyor', s->'result'->>'my_score')
            else format('KANIT_HATA 6 %s', s) end;
  insert into pg_temp._kanit(line) values (k);

  -- Yeniden başlatma: sunulmuş sorular artık içerikli.
  r := public.start_tournament_match(m);
  k := case when (r->>'finished')::boolean and r->'questions'->2->>'prompt' <> ''
            then 'KANIT_OK 7 yeniden açılış: bitti, sunulan sorular içerikli'
            else format('KANIT_HATA 7 %s', r) end;
  insert into pg_temp._kanit(line) values (k);

  begin
    perform public.answer_tournament_question(m, 3, 'A');
    insert into pg_temp._kanit(line) values ('KANIT_HATA 8 tekrar cevap kabul edildi');
  exception when others then
    insert into pg_temp._kanit(line) values (
      case when sqlerrm = 'Already answered' then 'KANIT_OK 8 tekrar cevap: Already answered'
           else format('KANIT_HATA 8 %s', sqlerrm) end);
  end;

  -- Eski istemci skoru: açık hata, skor değişmez.
  select score_one into v_score_a from public.tournament_matches where id = m;
  begin
    perform public.submit_tournament_match(m, 600);
    insert into pg_temp._kanit(line) values ('KANIT_HATA 9 eski istemci skoru kabul edildi');
  exception when others then
    insert into pg_temp._kanit(line) values (
      case when sqlerrm = 'Update required'
             and (select score_one from public.tournament_matches where id = m) = v_score_a
           then format('KANIT_OK 9 eski istemci: Update required, skor %s değişmedi', v_score_a)
           else format('KANIT_HATA 9 %s', sqlerrm) end);
  end;

  -- B: ilk soru süre doldu (sunumsuz TIMEOUT kabul), kalanlar doğru.
  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  r := public.start_tournament_match(m);
  k := case when r->>'role' = 'opponent' and (r->>'answered')::int = 0
            then 'KANIT_OK 10 B başlatma: rol opponent, 0 cevap'
            else format('KANIT_HATA 10 %s', r) end;
  insert into pg_temp._kanit(line) values (k);
  s := public.answer_tournament_question(m, 0, 'TIMEOUT');
  for i in 1..3 loop
    perform public.present_tournament_question(m, i);
    select q.correct_option into correct from public.questions q
     where q.id = (select question_ids[i + 1] from public.tournament_match_questions where match_id = m);
    s := public.answer_tournament_question(m, i, correct);
  end loop;
  select score_two into v_score_b from public.tournament_matches where id = m;
  k := case when v_score_b between 300 and 450 and s->'result'->>'status' = 'completed'
             and s->'result'->>'outcome' = 'loss'
            then format('KANIT_OK 11 B: 3 doğru = %s, kaybetti', v_score_b)
            else format('KANIT_HATA 11 skor %s yanıt %s', v_score_b, s) end;
  insert into pg_temp._kanit(line) values (k);

  k := case when (select status = 'completed' and winner_id = a from public.tournament_matches where id = m)
             and (select status = 'finished' and champion_id = a from public.tournaments where id = t)
            then 'KANIT_OK 12 maç kapandı, kupa bitti, şampiyon A'
            else 'KANIT_HATA 12 maç/kupa durumu' end;
  insert into pg_temp._kanit(line) values (k);

  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  s := public.claim_tournament_reward();
  r := public.claim_tournament_reward();
  k := case when (s->>'amount')::int = 200 and (r->>'amount')::int = 0
             and (r->>'already_claimed')::boolean
             and (r->>'paid_amount')::int = 200
            then 'KANIT_OK 13 şampiyon 200 jeton aldı; ikinci talep 0, zaten alındı (200)'
            else format('KANIT_HATA 13 %s %s', s, r) end;
  insert into pg_temp._kanit(line) values (k);

  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  s := public.claim_tournament_reward();
  k := case when (s->>'amount')::int = 0 then 'KANIT_OK 14 kaybeden ödül almaz'
            else format('KANIT_HATA 14 %s', s) end;
  insert into pg_temp._kanit(line) values (k);

  -- Kupa içinde soru tekrarı yok: aynı kupada ikinci maç, ilk maçın
  -- sorularını almaz. (A ile B'yi yeni bir maça koyup başlatır.)
  declare
    m2 uuid;
    overlap int;
  begin
    insert into public.tournament_matches (tournament_id, round, slot, player_one, player_two, deadline)
    values (t, 2, 9, a, b, now() + interval '24 hours') returning id into m2;
    update public.tournaments set status = 'running' where id = t;
    perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
    perform public.start_tournament_match(m2);
    select count(*) into overlap
    from unnest((select question_ids from public.tournament_match_questions where match_id = m2)) as x(x)
    where x = any ((select question_ids from public.tournament_match_questions where match_id = m)::uuid[]);
    k := case when overlap = 0 then 'KANIT_OK 16 aynı kupada sonraki maç önceki soruları almaz'
              else format('KANIT_HATA 16 %s ortak soru', overlap) end;
    insert into pg_temp._kanit(line) values (k);
  end;

  -- Yalnız sunulmamış sorulara "süre doldu" gönderen şampiyon ödül alamaz.
  declare
    t3 uuid; m3 uuid;
  begin
    insert into public.tournaments (size, min_size, status, started_at)
    values (2, 2, 'running', now()) returning id into t3;
    insert into public.tournament_entries (tournament_id, player_id, display_name)
    values (t3, a, 'Test Ajan 4'), (t3, b, 'Rojd');
    insert into public.tournament_matches (tournament_id, round, slot, player_one, player_two, deadline)
    values (t3, 1, 0, a, b, now() + interval '24 hours') returning id into m3;
    perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
    perform public.start_tournament_match(m3);
    for i in 0..3 loop
      perform public.answer_tournament_question(m3, i, 'TIMEOUT');
    end loop;
    update public.tournaments set status = 'finished', finished_at = now() + interval '1 minute', champion_id = a where id = t3;
    s := public.claim_tournament_reward();
    k := case when (s->>'amount')::int = 0 then 'KANIT_OK 18 görmeden süre doldu gönderen şampiyon ödül almaz'
              else format('KANIT_HATA 18 %s', s) end;
    insert into pg_temp._kanit(line) values (k);
  end;

  -- Hiç oynamadan şampiyon olan (bay + rakip gelmedi) ödül alamaz.
  declare
    t2 uuid;
  begin
    insert into public.tournaments (size, min_size, status, started_at, finished_at, champion_id)
    values (2, 2, 'finished', now(), now(), b) returning id into t2;
    perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
    s := public.claim_tournament_reward();
    k := case when (s->>'amount')::int = 0 then 'KANIT_OK 17 oynamadan şampiyon olan ödül almaz'
              else format('KANIT_HATA 17 %s', s) end;
    insert into pg_temp._kanit(line) values (k);
  end;

  k := case when not has_table_privilege('authenticated', 'public.tournament_match_answers', 'select')
             and not has_table_privilege('authenticated', 'public.tournament_match_questions', 'select')
             and not has_function_privilege('authenticated', 'public.advance_tournament(uuid)', 'execute')
             and not has_function_privilege('anon', 'public.answer_tournament_question(uuid,integer,text)', 'execute')
             and has_function_privilege('authenticated', 'public.answer_tournament_question(uuid,integer,text)', 'execute')
             and position('for update' in pg_get_functiondef('public.advance_tournament(uuid)'::regprocedure)) > 0
            then 'KANIT_OK 15 yetkiler kapalı; tur ilerletmesi kupayı kilitler'
            else 'KANIT_HATA 15 yetki/kilit' end;
  insert into pg_temp._kanit(line) values (k);

  perform set_config('request.jwt.claims', '{}', true);
end $$;
select line from pg_temp._kanit order by n;
