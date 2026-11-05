-- 2.1.2 W2 (ChatGPT Pro denetimi alan 1 #3-#4, alan 2 #2-#6, #13-#14):
-- REKABETÇİ MODLARDA CEVAP ANAHTARI İSTEMCİYE VERİLMEZ. YAZILDI, CANLIYA UYGULANMADI.
-- Geri alma: geri_al/2026-11-16_rekabet_sunum_geri.sql
-- Eski yolların kapatılması AYRI göç: 2026-11-17_rekabet_sunum_guard.sql (2.1.2 yayılınca).
--
-- Bu göç YALNIZ YENİ nesne yaratır; mevcut hiçbir işlevin gövdesine, imzasına ya da
-- dönüş biçimine dokunmaz (canlıdaki build 45 aynen çalışır). Bu yüzden gövde md5
-- ön koşulu yoktur; onun yerine çağrılan mevcut işlevlerin md5'i göç içinde okunup
-- sonda DEĞİŞMEDİĞİ denetlenir (2026-11-07_idempotency_tur9.sql ile aynı gerekçe).
--
-- Kusur (günün yarışması): get_verified_daily_question_ids() 10 gerçek soru kimliğini
-- verir; istemci kimlikleri yerel bankayla eşleyip correctAnswer'ı pakette bulur ve
-- 10 doğruyu saniyeler içinde gönderebilir. Sunucu sunum ve soru başına süre aramaz.
-- Çözüm (yeni yol): soru metni+şıklar sunucudan, SUNULDUĞU ANDA, doğru şık OLMADAN
-- (present_verified_daily_question); cevabı sunucu değerlendirir, doğru şık cevaptan
-- SONRA döner (answer_verified_daily_question); gerçek kimlik de ancak cevaptan sonra.
-- Süre sunucuda: sunum kaydından cevaba 20 sn (+5 sn ağ payı), aşan cevap yanlış.
--
-- Aynı yolda kapanan akış kusurları:
--  * Yarıda kesilen tura devam (alan 2 #3): start_verified_daily_v2 günün oturumunu
--    ya yaratır ya da kaldığı yerden döndürür (cevaplanan sayı, seri, süre).
--  * Gece yarısı (#6): oturum BAŞLADIĞI güne yazılır; cevap ve sonuç, oturumun 1 saatlik
--    ömrü içinde gün değişse de kabul edilir; sonuç oturumun gününe yazılır.
--  * Baştan süresi dolmuş oturum (#14): yeni oturum ilk açıklama anına DEĞİL, yaratıldığı
--    ana başlar (kimlik açıklaması yeni yolda yoktur).
--  * Sonuç gönderimi (#5): submit_verified_daily_event_result_v2 idempotent; kalıcı tur
--    kimliği sunucuda durduğundan istemci tekrar tekrar deneyebilir ve uygulama yeniden
--    açılınca (start_verified_daily_v2 'submitted:false, completed:true') tamamlayabilir.
--
-- Kusur (oda, sırayla düello): get_room_questions / start|create|accept|resume_async_duel
-- sarmalayıcıları metni gizler ama SUNULMAMIŞ soruların GERÇEK kimliğini döndürür;
-- yerel bankayla eşlenip cevaplar önceden öğrenilir. Yeni yol: gizli sorular için
-- yalnız opak, kararlı SIRA BELİRTECİ (md5'ten türeyen UUID biçimli, gerçek kimliğe
-- geri çevrilemez, hiçbir yerel soruyla eşleşmez): get_room_questions_v2 ve
-- *_masked düello sarmalayıcıları. Gerçek kimlik soru sunulunca gelir.
--
-- Turnuva (alan 1 #4 / alan 2 #9): başlangıç yanıtı zaten 'pending-N' yer tutucu verir;
-- içerik present_tournament_question ile gelir. Kalan açık, sunulan sorunun METNİNİN
-- yerel bankayla eşlenmesidir (istemci sunum anında cevabı bulabilir): bu, cevap
-- anahtarlı bir paketle çözülemez; yalnız "turnuva havuzu pakette olmayan sorulardan"
-- kararıyla kapanır (içerik kararı, bu göçün dışında; applied.md notu).
begin;

set local lock_timeout = '10s';

do $w2_onkosul$
begin
  if to_regclass('public.profiles') is null
     or to_regclass('public.verified_quiz_sessions') is null
     or to_regclass('public.verified_quiz_answers') is null
     or to_regclass('public.verified_daily_event_results') is null
     or to_regclass('public.verified_daily_question_sets') is null
     or to_regclass('public.verified_quiz_cutover') is null
     or to_regprocedure('public.app_today()') is null
     or to_regprocedure('public.get_room_questions(uuid)') is null
     or to_regprocedure('public.start_async_duel(text)') is null
     or to_regprocedure('public.start_async_duel(text,uuid)') is null
     or to_regprocedure('public.create_async_duel_challenge(text,uuid)') is null
     or to_regprocedure('public.create_async_duel_challenge(text,uuid,uuid)') is null
     or to_regprocedure('public.accept_async_duel_challenge(text)') is null
     or to_regprocedure('public.resume_my_async_duel(uuid)') is null then
    raise exception 'w2: beklenen canlı nesneler eksik (solo_daily_verified / room_duel_guards / tur9 uygulanmış olmalı)';
  end if;
  if to_regclass('public.verified_quiz_presentations') is not null
     or to_regprocedure('public._w2_opaque_id(text,integer)') is not null
     or to_regprocedure('public._w2_daily_set(date)') is not null
     or to_regprocedure('public._w2_daily_state(public.verified_quiz_sessions)') is not null
     or to_regprocedure('public.start_verified_daily_v2()') is not null
     or to_regprocedure('public.present_verified_daily_question(uuid,integer)') is not null
     or to_regprocedure('public.answer_verified_daily_question(uuid,integer,text)') is not null
     or to_regprocedure('public.submit_verified_daily_event_result_v2(uuid)') is not null
     or to_regprocedure('public.get_room_questions_v2(uuid)') is not null
     or to_regprocedure('public._w2_mask_duel_payload(jsonb)') is not null
     or to_regprocedure('public.start_async_duel_masked(text,uuid)') is not null
     or to_regprocedure('public.create_async_duel_challenge_masked(text,uuid,uuid)') is not null
     or to_regprocedure('public.accept_async_duel_challenge_masked(text)') is not null
     or to_regprocedure('public.resume_my_async_duel_masked(uuid)') is not null then
    raise exception 'w2: yaratılacak nesnelerden biri zaten var; göç durdu';
  end if;
end
$w2_onkosul$;

create temp table w2_mevcut (imza text primary key, md5 text not null) on commit drop;
insert into w2_mevcut
select s, md5(pg_get_functiondef(to_regprocedure(s))) from unnest(array[
  'public.get_verified_daily_question_ids()',
  'public.start_verified_quiz(uuid,uuid[],boolean,uuid)',
  'public.answer_verified_quiz(uuid,uuid,text)',
  'public.submit_verified_daily_event_result(uuid)',
  'public.get_room_questions(uuid)',
  'public.start_async_duel(text)', 'public.start_async_duel(text,uuid)',
  'public.create_async_duel_challenge(text,uuid)',
  'public.create_async_duel_challenge(text,uuid,uuid)',
  'public.accept_async_duel_challenge(text)', 'public.resume_my_async_duel(uuid)']) s;

-- Sunum kaydı: soru sunucudan ilk açıldığı an (süre buradan ölçülür).
create table public.verified_quiz_presentations (
  session_id uuid not null references public.verified_quiz_sessions(id) on delete cascade,
  question_index integer not null check (question_index >= 0),
  presented_at timestamptz not null default clock_timestamp(),
  primary key (session_id, question_index)
);
alter table public.verified_quiz_presentations enable row level security;
revoke all on table public.verified_quiz_presentations from public, anon, authenticated;
grant all on table public.verified_quiz_presentations to service_role;

-- Opak sıra belirteci: gerçek kimliğe geri çevrilemez, aynı (kapsam, sıra) hep aynı.
create function public._w2_opaque_id(p_scope text, p_index integer)
returns uuid
language sql
immutable
set search_path = public, pg_temp
as $function$
  select md5('w2:' || coalesce(p_scope, '') || ':' || coalesce(p_index, 0)::text)::uuid;
$function$;

-- Günün 10 sorusu (bir kez rastgele seçilir; eski işlevle AYNI kilit ve AYNI tablo).
-- Kimlik açıklaması (verified_daily_disclosures) yazmaz: yeni yolda süre oturumdan ölçülür.
create function public._w2_daily_set(p_day date)
returns uuid[]
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare v_ids uuid[];
begin
  perform pg_advisory_xact_lock(hashtext('verified_daily_question_set'), p_day - date '2000-01-01');
  select question_ids into v_ids from public.verified_daily_question_sets where day = p_day;
  if found then return v_ids; end if;
  select array_agg(id order by seed, id) into v_ids from (
    select q.id, random() as seed
    from public.questions q join public.categories c on c.id = q.category_id
    where q.is_approved = true and c.is_active = true
      and q.correct_option in ('A', 'B', 'C', 'D')
      and coalesce(q.question_type, 'multiple_choice') in ('multiple_choice', 'true_false')
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (q.question_type = 'true_false' and q.correct_option in ('A', 'B')
        or coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-'))
    order by seed, q.id limit 10
  ) selected;
  if coalesce(cardinality(v_ids), 0) <> 10 then raise exception 'No questions'; end if;
  insert into public.verified_daily_question_sets(day, question_ids) values (p_day, v_ids);
  return v_ids;
end;
$function$;

create function public._w2_daily_state(p_session public.verified_quiz_sessions)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $function$
  select jsonb_build_object(
    'available', true,
    'round_id', p_session.client_round_id,
    'day', p_session.day,
    'total', cardinality(p_session.question_ids),
    'answered', p_session.answered_count,
    'correct', p_session.correct_count,
    'current_streak', p_session.current_streak,
    'best_streak', p_session.best_streak,
    'completed', p_session.completed_at is not null,
    'expired', p_session.completed_at is null
      and p_session.started_at + interval '1 hour' < clock_timestamp(),
    'submitted', exists (select 1 from public.verified_daily_event_results r
      where r.session_id = p_session.id),
    'elapsed_ms', greatest(0, floor(extract(epoch from
      (coalesce(p_session.completed_at, clock_timestamp()) - p_session.started_at)) * 1000))::bigint
  );
$function$;

-- Günün oturumunu yaratır ya da kaldığı yerden döndürür. Soru kimliği/içeriği DÖNMEZ.
create function public.start_verified_daily_v2()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_day date := public.app_today();
  v_first date;
  s public.verified_quiz_sessions%rowtype;
  v_ids uuid[];
  v_opts text[];
begin
  if v_uid is null then raise exception 'Authenticated user required'; end if;
  select first_day into v_first from public.verified_quiz_cutover where singleton;
  if v_first is null or v_day < v_first then
    return jsonb_build_object('available', false, 'reason', 'before_cutover');
  end if;
  perform 1 from public.profiles where id = v_uid for update;
  if not found then raise exception 'Profile missing'; end if;

  -- Bugünün oturumu; yoksa dünün, gece yarısını aşan ve hâlâ ömrü olan (1 saat)
  -- yarım/gönderilmemiş oturumu (başlangıç gününe yazılacak).
  select * into s from public.verified_quiz_sessions q
  where q.user_id = v_uid and q.is_daily
    and (q.day = v_day
      or (q.day = v_day - 1
        and not exists (select 1 from public.verified_daily_event_results r where r.session_id = q.id)
        and coalesce(q.completed_at, q.started_at) + interval '1 hour' > clock_timestamp()))
  order by q.day desc
  limit 1;
  if found then
    return public._w2_daily_state(s) || jsonb_build_object('resumed', true);
  end if;

  v_ids := public._w2_daily_set(v_day);
  select array_agg(q.correct_option order by r.ordinality) into v_opts
  from unnest(v_ids) with ordinality r(id, ordinality)
  join public.questions q on q.id = r.id
  where q.correct_option in ('A', 'B', 'C', 'D');
  if cardinality(v_opts) is distinct from cardinality(v_ids) then
    raise exception 'Unverifiable question set';
  end if;
  insert into public.verified_quiz_sessions
    (user_id, client_round_id, day, is_daily, question_ids, correct_options, started_at)
  values (v_uid, gen_random_uuid(), v_day, true, v_ids, v_opts, clock_timestamp())
  on conflict do nothing;
  select * into s from public.verified_quiz_sessions q
  where q.user_id = v_uid and q.is_daily and q.day = v_day;
  if not found then raise exception 'Daily session unavailable'; end if;
  return public._w2_daily_state(s) || jsonb_build_object('resumed', false);
end;
$function$;

-- Sıradaki soruyu SUNAR: metin+şıklar döner, doğru şık ve gerçek kimlik DÖNMEZ.
create function public.present_verified_daily_question(p_round uuid, p_index integer)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  s public.verified_quiz_sessions%rowtype;
  v_at timestamptz;
  v_question jsonb;
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  select * into s from public.verified_quiz_sessions
    where user_id = auth.uid() and client_round_id = p_round and is_daily for update;
  if not found then raise exception 'Verified session missing'; end if;
  if s.completed_at is not null then raise exception 'Round completed'; end if;
  if s.started_at + interval '1 hour' < clock_timestamp() then
    raise exception 'Session expired';
  end if;
  if p_index is null or p_index <> s.answered_count
     or p_index >= cardinality(s.question_ids) then
    raise exception 'Invalid index';
  end if;
  insert into public.verified_quiz_presentations(session_id, question_index)
    values (s.id, p_index) on conflict do nothing;
  select presented_at into v_at from public.verified_quiz_presentations
    where session_id = s.id and question_index = p_index;
  select jsonb_build_object(
    'id', public._w2_opaque_id(s.id::text, p_index)::text,
    'index', p_index,
    'category_name', coalesce(c.name, 'Ziman'),
    'prompt', q.prompt,
    'option_a', q.option_a, 'option_b', q.option_b,
    'option_c', q.option_c, 'option_d', q.option_d,
    'question_type', q.question_type, 'image_url', q.image_url,
    'difficulty', q.difficulty) into v_question
  from public.questions q left join public.categories c on c.id = q.category_id
  where q.id = s.question_ids[p_index + 1];
  if v_question is null then raise exception 'Question unavailable'; end if;
  return jsonb_build_object(
    'presented_at', v_at,
    'elapsed_ms', greatest(0, floor(extract(epoch from (clock_timestamp() - v_at)) * 1000))::integer,
    'limit_ms', 20000,
    'question', v_question);
end;
$function$;

-- Cevabı SUNUCU değerlendirir; doğru şık, gerçek kimlik ve açıklama cevaptan SONRA döner.
create function public.answer_verified_daily_question(p_round uuid, p_index integer, p_choice text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  s public.verified_quiz_sessions%rowtype;
  a public.verified_quiz_answers%rowtype;
  v_choice text;
  v_presented timestamptz;
  v_correct boolean;
  v_streak integer;
  v_next integer;
  v_done boolean;
  v_reveal jsonb;
  v_limit_ms constant integer := 20000;
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  v_choice := case when p_choice is null or p_choice = 'TIMEOUT' then '' else p_choice end;
  if v_choice not in ('', 'A', 'B', 'C', 'D') then raise exception 'Invalid choice'; end if;
  select * into s from public.verified_quiz_sessions
    where user_id = auth.uid() and client_round_id = p_round and is_daily for update;
  if not found then raise exception 'Verified session missing'; end if;
  if p_index is null or p_index < 0 or p_index >= cardinality(s.question_ids) then
    raise exception 'Invalid index';
  end if;

  select jsonb_build_object(
    'question_id', q.id,
    'explanation', q.explanation, 'explanation_ku', q.explanation_ku,
    'explanation_tr', q.explanation_tr)
  into v_reveal from public.questions q where q.id = s.question_ids[p_index + 1];

  -- Yeniden gönderim (yanıtı kaybolan çağrı): ilk cevabı döndürür, ikinci puan üretmez.
  select * into a from public.verified_quiz_answers
    where session_id = s.id and question_index = p_index;
  if found then
    return coalesce(v_reveal, '{}'::jsonb) || jsonb_build_object(
      'accepted', true, 'already_answered', true,
      'is_correct', a.is_correct,
      'correct_option', s.correct_options[p_index + 1],
      'answered', s.answered_count, 'correct', s.correct_count,
      'completed', s.completed_at is not null);
  end if;

  if s.started_at + interval '1 hour' < clock_timestamp() then
    raise exception 'Session expired';
  end if;
  v_next := s.answered_count + 1;
  if p_index <> v_next - 1 then raise exception 'Question out of sequence'; end if;

  select presented_at into v_presented from public.verified_quiz_presentations
    where session_id = s.id and question_index = p_index;
  -- İçeriği görmeden yalnız "süre doldu" gönderilebilir; sunumu atlayıp cevap vermek
  -- süre sınırını aşmanın yolu olmasın.
  if v_presented is null and v_choice <> '' then raise exception 'Not presented'; end if;
  v_correct := v_choice <> '' and v_choice = s.correct_options[v_next];
  -- Süre sunucuda: sunum kaydından bu yana limit + 5 sn ağ payı.
  if v_correct and extract(epoch from (clock_timestamp() - v_presented)) * 1000 > v_limit_ms + 5000 then
    v_correct := false;
  end if;
  v_streak := case when v_correct then s.current_streak + 1 else 0 end;
  v_done := v_next = cardinality(s.question_ids);
  insert into public.verified_quiz_answers(session_id, question_index, question_id, choice, is_correct)
    values (s.id, p_index, s.question_ids[v_next], v_choice, v_correct);
  update public.verified_quiz_sessions set
    answered_count = v_next,
    correct_count = correct_count + case when v_correct then 1 else 0 end,
    current_streak = v_streak, best_streak = greatest(best_streak, v_streak),
    completed_at = case when v_done then clock_timestamp() end
  where id = s.id;
  return coalesce(v_reveal, '{}'::jsonb) || jsonb_build_object(
    'accepted', true, 'already_answered', false,
    'is_correct', v_correct,
    'correct_option', s.correct_options[v_next],
    'answered', v_next, 'correct', s.correct_count + case when v_correct then 1 else 0 end,
    'completed', v_done);
end;
$function$;

-- Günlük sonucu OTURUMUN BAŞLADIĞI güne yazar; idempotent, tekrar denenebilir.
create function public.submit_verified_daily_event_result_v2(p_round uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare s public.verified_quiz_sessions%rowtype;
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  select * into s from public.verified_quiz_sessions
    where user_id = auth.uid() and client_round_id = p_round and is_daily for update;
  if not found then return jsonb_build_object('submitted', false, 'reason', 'missing'); end if;
  if s.completed_at is null or s.answered_count <> cardinality(s.question_ids) then
    return jsonb_build_object('submitted', false, 'reason', 'incomplete');
  end if;
  if s.day < (select first_day from public.verified_quiz_cutover where singleton) then
    return jsonb_build_object('submitted', false, 'reason', 'before_cutover');
  end if;
  if exists (select 1 from public.verified_daily_event_results r where r.session_id = s.id) then
    return jsonb_build_object('submitted', true, 'day', s.day);
  end if;
  -- Başka günün sonucu yalnız bitişten sonraki 1 saat içinde yazılır (ek süre).
  if s.day <> public.app_today() and s.completed_at + interval '1 hour' < clock_timestamp() then
    return jsonb_build_object('submitted', false, 'reason', 'late');
  end if;
  insert into public.verified_daily_event_results
    (day, user_id, correct_count, total_count, seconds, session_id)
  values (s.day, auth.uid(), s.correct_count, cardinality(s.question_ids),
    greatest(1, ceil(extract(epoch from (s.completed_at - s.started_at)))::integer), s.id)
  on conflict (day, user_id) do nothing;
  return jsonb_build_object('submitted', exists (select 1 from public.verified_daily_event_results r
    where r.session_id = s.id), 'day', s.day);
end;
$function$;

-- Oda: sunulmamış soruların kimliği opak sıra belirteci olur.
create function public.get_room_questions_v2(p_room_id uuid)
returns setof jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare row_data jsonb;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  for row_data in select * from public.get_room_questions(p_room_id) loop
    if row_data ->> 'content_hidden' = 'true' then
      row_data := jsonb_set(row_data, '{id}', to_jsonb(
        public._w2_opaque_id(p_room_id::text, coalesce((row_data ->> 'index')::integer, 0))::text));
    end if;
    return next row_data;
  end loop;
end;
$function$;

-- Düello: gizli sorular için opak sıra belirteci (gerçek kimlik present_v2 ile gelir).
create function public._w2_mask_duel_payload(p_payload jsonb)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $function$
  select case when jsonb_typeof(p_payload -> 'questions') = 'array' then
    jsonb_set(p_payload, '{questions}', coalesce((
      select jsonb_agg(
        case when t.q ->> 'content_hidden' = 'true' or coalesce(t.q ->> 'prompt', '') = ''
          then jsonb_set(t.q, '{id}', to_jsonb(public._w2_opaque_id(
            coalesce(p_payload ->> 'duel_id', ''),
            coalesce((t.q ->> 'index')::integer, (t.ord - 1)::integer))::text))
          else t.q end
        order by t.ord)
      from jsonb_array_elements(p_payload -> 'questions') with ordinality as t(q, ord)
    ), '[]'::jsonb))
  else p_payload end;
$function$;

create function public.start_async_duel_masked(p_category text default null, p_request_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  return public._w2_mask_duel_payload(case when p_request_id is null
    then public.start_async_duel(p_category)
    else public.start_async_duel(p_category, p_request_id) end);
end;
$function$;

create function public.create_async_duel_challenge_masked(
  p_category text default null, p_friend_id uuid default null, p_request_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  return public._w2_mask_duel_payload(case when p_request_id is null
    then public.create_async_duel_challenge(p_category, p_friend_id)
    else public.create_async_duel_challenge(p_category, p_friend_id, p_request_id) end);
end;
$function$;

create function public.accept_async_duel_challenge_masked(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  return public._w2_mask_duel_payload(public.accept_async_duel_challenge(p_code));
end;
$function$;

create function public.resume_my_async_duel_masked(p_duel_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  return public._w2_mask_duel_payload(public.resume_my_async_duel(p_duel_id));
end;
$function$;

-- Yetkiler: iç yardımcılar kimseye; yeni RPC'ler yalnız authenticated (+service_role).
revoke all on function public._w2_opaque_id(text, integer) from public, anon, authenticated;
revoke all on function public._w2_daily_set(date) from public, anon, authenticated;
revoke all on function public._w2_daily_state(public.verified_quiz_sessions) from public, anon, authenticated;
revoke all on function public._w2_mask_duel_payload(jsonb) from public, anon, authenticated;
revoke all on function public.start_verified_daily_v2() from public, anon;
revoke all on function public.present_verified_daily_question(uuid, integer) from public, anon;
revoke all on function public.answer_verified_daily_question(uuid, integer, text) from public, anon;
revoke all on function public.submit_verified_daily_event_result_v2(uuid) from public, anon;
revoke all on function public.get_room_questions_v2(uuid) from public, anon;
revoke all on function public.start_async_duel_masked(text, uuid) from public, anon;
revoke all on function public.create_async_duel_challenge_masked(text, uuid, uuid) from public, anon;
revoke all on function public.accept_async_duel_challenge_masked(text) from public, anon;
revoke all on function public.resume_my_async_duel_masked(uuid) from public, anon;
grant execute on function public.start_verified_daily_v2() to authenticated, service_role;
grant execute on function public.present_verified_daily_question(uuid, integer) to authenticated, service_role;
grant execute on function public.answer_verified_daily_question(uuid, integer, text) to authenticated, service_role;
grant execute on function public.submit_verified_daily_event_result_v2(uuid) to authenticated, service_role;
grant execute on function public.get_room_questions_v2(uuid) to authenticated, service_role;
grant execute on function public.start_async_duel_masked(text, uuid) to authenticated, service_role;
grant execute on function public.create_async_duel_challenge_masked(text, uuid, uuid) to authenticated, service_role;
grant execute on function public.accept_async_duel_challenge_masked(text) to authenticated, service_role;
grant execute on function public.resume_my_async_duel_masked(uuid) to authenticated, service_role;

do $w2_son$
declare r text;
begin
  -- SECURITY DEFINER, sabit search_path, sahip tablo sahibiyle aynı, anon/PUBLIC kapalı.
  foreach r in array array[
    'public._w2_daily_set(date)',
    'public.start_verified_daily_v2()',
    'public.present_verified_daily_question(uuid,integer)',
    'public.answer_verified_daily_question(uuid,integer,text)',
    'public.submit_verified_daily_event_result_v2(uuid)',
    'public.get_room_questions_v2(uuid)',
    'public.start_async_duel_masked(text,uuid)',
    'public.create_async_duel_challenge_masked(text,uuid,uuid)',
    'public.accept_async_duel_challenge_masked(text)',
    'public.resume_my_async_duel_masked(uuid)'
  ] loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r) and p.prosecdef
        and p.proconfig = array['search_path=public, pg_temp']
        and p.proowner = (select c.relowner from pg_class c
          where c.oid = 'public.verified_quiz_sessions'::regclass)
    ) then
      raise exception 'w2: % SECURITY DEFINER / search_path / sahip doğrulanamadı', r;
    end if;
    if has_function_privilege('anon', r, 'execute') or has_function_privilege('public', r, 'execute') then
      raise exception 'w2: % anon/PUBLIC EXECUTE açık', r;
    end if;
  end loop;
  foreach r in array array[
    'public._w2_opaque_id(text,integer)', 'public._w2_daily_set(date)',
    'public._w2_daily_state(public.verified_quiz_sessions)',
    'public._w2_mask_duel_payload(jsonb)'
  ] loop
    if has_function_privilege('authenticated', r, 'execute')
       or has_function_privilege('anon', r, 'execute') then
      raise exception 'w2: iç yardımcı % istemciye açık', r;
    end if;
  end loop;
  foreach r in array array[
    'public.start_verified_daily_v2()',
    'public.present_verified_daily_question(uuid,integer)',
    'public.answer_verified_daily_question(uuid,integer,text)',
    'public.submit_verified_daily_event_result_v2(uuid)',
    'public.get_room_questions_v2(uuid)',
    'public.start_async_duel_masked(text,uuid)',
    'public.create_async_duel_challenge_masked(text,uuid,uuid)',
    'public.accept_async_duel_challenge_masked(text)',
    'public.resume_my_async_duel_masked(uuid)'
  ] loop
    if not has_function_privilege('authenticated', r, 'execute') then
      raise exception 'w2: % authenticated EXECUTE kapalı', r;
    end if;
  end loop;
  if has_table_privilege('anon', 'public.verified_quiz_presentations', 'select,insert,update,delete')
     or has_table_privilege('authenticated', 'public.verified_quiz_presentations', 'select,insert,update,delete')
     or not (select c.relrowsecurity from pg_class c
       where c.oid = 'public.verified_quiz_presentations'::regclass) then
    raise exception 'w2: verified_quiz_presentations istemciye açık ya da RLS kapalı';
  end if;
  if exists (select 1 from w2_mevcut m
    where md5(pg_get_functiondef(to_regprocedure(m.imza))) <> m.md5) then
    raise exception 'w2: mevcut bir işlevin gövdesi değişti (bu göç değiştirmemeliydi)';
  end if;
end
$w2_son$;

commit;
