-- G5/G9: beyan edilen toplamlar yerine sunucu oturumu ve tekil cevaplar.
-- CANLIYA UYGULANMADI. Bu dosya uygulanırken mevcut tanımlar yedeklenir;
-- eski göçlerden fonksiyon gövdesi kopyalanmaz. Yerel tur göçsüz de çalışır.
-- Günlük resmi geçiş, uygulamayı izleyen İstanbul günü 00:00'da başlar.
begin;

create table if not exists public.g5g9_function_backup (
  signature text primary key,
  definition text not null,
  privileges jsonb not null
);
alter table public.g5g9_function_backup enable row level security;
revoke all on public.g5g9_function_backup from public, anon, authenticated;

do $backup$
declare
  v_signature text;
  v_oid oid;
begin
  foreach v_signature in array array[
    'public.claim_solo_reward(integer,integer,integer)',
    'public.claim_solo_reward(integer,integer,integer,uuid)',
    'public.submit_daily_event_result(integer,integer,integer)',
    'public.get_daily_event_board()'
  ] loop
    v_oid := to_regprocedure(v_signature);
    if v_oid is null then
      raise exception 'G5/G9 prerequisite missing: %', v_signature;
    end if;
    insert into public.g5g9_function_backup(signature, definition, privileges)
    select v_signature, pg_get_functiondef(v_oid),
      coalesce((select jsonb_agg(jsonb_build_object(
        'role', case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
        'grantable', a.is_grantable
      )) from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where a.privilege_type = 'EXECUTE'), '[]'::jsonb)
    from pg_proc p where p.oid = v_oid
    on conflict (signature) do nothing;
  end loop;
end;
$backup$;

create table if not exists public.verified_quiz_cutover (
  singleton boolean primary key default true check (singleton),
  first_day date not null
);
insert into public.verified_quiz_cutover(singleton, first_day)
values (true, public.app_today() + 1) on conflict do nothing;

create table if not exists public.verified_daily_question_sets (
  day date primary key,
  question_ids uuid[] not null check (cardinality(question_ids) = 10)
);

-- Soru kimlikleri ilk kez açıklanınca süre başlar. Oyuncu kimlikleri
-- önceden çözüp daha sonra oturum açarak 1 saniye derece üretemez.
create table if not exists public.verified_daily_disclosures (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  first_seen_at timestamptz not null default clock_timestamp(),
  primary key(user_id, day)
);

create table if not exists public.verified_solo_selections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question_ids uuid[] not null,
  created_at timestamptz not null default clock_timestamp(),
  used_by_round uuid
);

create table if not exists public.verified_quiz_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_round_id uuid not null,
  day date not null default public.app_today(),
  is_daily boolean not null,
  question_ids uuid[] not null,
  correct_options text[] not null,
  answered_count integer not null default 0,
  correct_count integer not null default 0,
  current_streak integer not null default 0,
  best_streak integer not null default 0,
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  reward_result jsonb,
  unique(user_id, client_round_id),
  check (cardinality(question_ids) between 1 and 50),
  check (cardinality(question_ids) = cardinality(correct_options)),
  check (answered_count between 0 and cardinality(question_ids))
);
create unique index if not exists verified_quiz_one_daily_attempt
  on public.verified_quiz_sessions(user_id, day) where is_daily;

create table if not exists public.verified_quiz_answers (
  session_id uuid not null references public.verified_quiz_sessions(id) on delete cascade,
  question_index integer not null,
  question_id uuid not null,
  choice text not null,
  is_correct boolean not null,
  answered_at timestamptz not null default clock_timestamp(),
  primary key(session_id, question_index),
  unique(session_id, question_id)
);

-- Eski beyanlar aynı tabloya taşınmaz. Bu tablo yalnız doğrulanmış yoldan
-- doldurulur; eski günlerin birincisi de resmî panoya karışmaz.
create table if not exists public.verified_daily_event_results (
  day date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  correct_count integer not null,
  total_count integer not null,
  seconds integer not null,
  created_at timestamptz not null default clock_timestamp(),
  session_id uuid not null unique references public.verified_quiz_sessions(id),
  primary key(day, user_id),
  check (total_count = 10 and correct_count between 0 and 10 and seconds >= 1)
);

do $tables$
declare v_table text;
begin
  foreach v_table in array array[
    'verified_quiz_cutover', 'verified_daily_question_sets', 'verified_solo_selections',
    'verified_daily_disclosures',
    'verified_quiz_sessions', 'verified_quiz_answers',
    'verified_daily_event_results'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on public.%I from public, anon, authenticated', v_table);
  end loop;
end;
$tables$;

create or replace function public.get_verified_daily_question_ids()
returns uuid[] language plpgsql security definer
set search_path = public, pg_temp
as $function$
declare v_ids uuid[]; v_day date := public.app_today();
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  insert into public.verified_daily_disclosures(user_id, day) values(auth.uid(), v_day)
    on conflict(user_id, day) do nothing;
  perform pg_advisory_xact_lock(hashtext('verified_daily_question_set'), v_day - date '2000-01-01');
  select question_ids into v_ids from public.verified_daily_question_sets where day = v_day;
  if found then return v_ids; end if;
  select array_agg(id order by seed, id) into v_ids from (
    -- Günün seti bir kez rastgele seçilir; public UUID+gün karmasıyla
    -- yarının soruları çevrimdışı önceden hesaplanamaz.
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
  insert into public.verified_daily_question_sets(day, question_ids) values (v_day, v_ids);
  return v_ids;
end;
$function$;

-- Soru listesini istemci seçemez; sunucu rastgele seçip tek kullanımlık
-- bir bilet üretir. Biletin yanıtında doğru şık yoktur.
create or replace function public.prepare_verified_solo_questions(p_category text, p_limit integer)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $function$
declare v_ids uuid[]; v_id uuid; v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authenticated user required'; end if;
  if p_limit is null or p_limit not between 1 and 50 then raise exception 'Invalid question count'; end if;
  perform 1 from public.profiles where id = v_uid for update;
  if not found then raise exception 'Profile missing'; end if;
  if (select count(*) from public.verified_solo_selections
      where user_id = v_uid and created_at > clock_timestamp() - interval '1 day') >= 100 then
    raise exception 'Daily selection limit';
  end if;
  select array_agg(id order by seed) into v_ids from (
    select q.id, random() as seed from public.questions q
    join public.categories c on c.id = q.category_id
    where q.is_approved = true and c.is_active = true
      and (p_category is null or p_category = 'Tevlihev' or c.name = p_category)
      and q.correct_option in ('A','B','C','D')
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (q.question_type = 'true_false' and q.correct_option in ('A','B')
        or coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-'))
    order by seed limit p_limit
  ) selected;
  if coalesce(cardinality(v_ids), 0) <> p_limit then raise exception 'No questions'; end if;
  insert into public.verified_solo_selections(user_id, question_ids) values(v_uid, v_ids)
    returning id into v_id;
  return jsonb_build_object('selection_id', v_id, 'question_ids', v_ids);
end;
$function$;

create or replace function public.start_verified_quiz(
  p_client_round_id uuid, p_question_ids uuid[], p_daily boolean, p_selection_id uuid
) returns uuid language plpgsql security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid uuid := auth.uid(); v_id uuid; v_options text[];
  v_existing public.verified_quiz_sessions%rowtype;
begin
  if v_uid is null then raise exception 'Authenticated user required'; end if;
  if p_client_round_id is null or p_daily is null
    or coalesce(cardinality(p_question_ids), 0) not between 1 and 50
    or cardinality(p_question_ids) <> (select count(distinct x) from unnest(p_question_ids) x)
  then raise exception 'Invalid round'; end if;
  select * into v_existing from public.verified_quiz_sessions
    where user_id = v_uid and client_round_id = p_client_round_id;
  if found then
    if v_existing.question_ids <> p_question_ids or v_existing.is_daily <> p_daily then
      raise exception 'Round identity mismatch';
    end if;
    return v_existing.id;
  end if;
  -- Geçiş günü yalnız yerel çalışma: yarın başlayan resmî sıralama için
  -- bugün tur açıp yarına taşıma yok. Tek günlük hak yarın harcanır.
  if p_daily and public.app_today() <
    (select first_day from public.verified_quiz_cutover where singleton) then
    raise exception 'Verified daily starts next day';
  end if;
  if p_daily and p_question_ids <> public.get_verified_daily_question_ids() then
    raise exception 'Daily question set mismatch';
  end if;
  if not p_daily then
    perform 1 from public.verified_solo_selections
      where id = p_selection_id and user_id = v_uid
        and question_ids = p_question_ids and used_by_round is null
        and created_at > clock_timestamp() - interval '10 minutes'
      for update;
    if not found then raise exception 'Server selection required'; end if;
  end if;
  -- Bir kullanıcının çok sayıda yarım oturum üretmesini de sınırla.
  perform 1 from public.profiles where id = v_uid for update;
  if not found then raise exception 'Profile missing'; end if;
  if (select count(*) from public.verified_quiz_sessions
      where user_id = v_uid and day = public.app_today()) >= 100 then
    raise exception 'Daily session limit';
  end if;
  select array_agg(q.correct_option order by requested.ordinality) into v_options
  from unnest(p_question_ids) with ordinality requested(id, ordinality)
  join public.questions q on q.id = requested.id
  where q.is_approved = true and q.correct_option in ('A','B','C','D');
  if cardinality(v_options) is distinct from cardinality(p_question_ids) then
    raise exception 'Unverifiable question set';
  end if;
  insert into public.verified_quiz_sessions
    (user_id, client_round_id, is_daily, question_ids, correct_options, started_at)
  values (v_uid, p_client_round_id, p_daily, p_question_ids, v_options,
    case when p_daily then (select first_seen_at from public.verified_daily_disclosures
      where user_id = v_uid and day = public.app_today()) else clock_timestamp() end)
  on conflict (user_id, client_round_id) do nothing
  returning id into v_id;
  if v_id is null then
    select * into v_existing from public.verified_quiz_sessions
      where user_id = v_uid and client_round_id = p_client_round_id;
    if v_existing.question_ids <> p_question_ids or v_existing.is_daily <> p_daily then
      raise exception 'Round identity mismatch';
    end if;
    v_id := v_existing.id;
  end if;
  if not p_daily then
    update public.verified_solo_selections set used_by_round = p_client_round_id
      where id = p_selection_id;
  end if;
  return v_id;
end;
$function$;

create or replace function public.answer_verified_quiz(
  p_client_round_id uuid, p_question_id uuid, p_choice text
) returns boolean language plpgsql security definer
set search_path = public, pg_temp
as $function$
declare
  v_session public.verified_quiz_sessions%rowtype;
  v_correct boolean; v_streak integer; v_next integer;
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  select * into v_session from public.verified_quiz_sessions
    where user_id = auth.uid() and client_round_id = p_client_round_id for update;
  if not found then raise exception 'Verified session missing'; end if;
  -- Yeniden gönderim ilk cevabı değiştirmez, ikinci puan üretmez.
  if exists(select 1 from public.verified_quiz_answers
    where session_id = v_session.id and question_id = p_question_id) then return true; end if;
  if v_session.started_at + interval '1 hour' < clock_timestamp()
     or v_session.day <> public.app_today() then raise exception 'Session expired'; end if;
  v_next := v_session.answered_count + 1;
  if v_next > cardinality(v_session.question_ids)
     or p_question_id is distinct from v_session.question_ids[v_next]
  then raise exception 'Question out of sequence'; end if;
  v_correct := coalesce(p_choice = v_session.correct_options[v_next], false);
  v_streak := case when v_correct then v_session.current_streak + 1 else 0 end;
  insert into public.verified_quiz_answers
    (session_id, question_index, question_id, choice, is_correct)
  values (v_session.id, v_next - 1, p_question_id, coalesce(p_choice, ''), v_correct);
  update public.verified_quiz_sessions set
    answered_count = v_next,
    correct_count = correct_count + case when v_correct then 1 else 0 end,
    current_streak = v_streak, best_streak = greatest(best_streak, v_streak),
    completed_at = case when v_next = cardinality(question_ids) then clock_timestamp() end
  where id = v_session.id;
  return true;
end;
$function$;

create or replace function public.claim_verified_solo_reward(p_client_round_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $function$
declare
  v_session public.verified_quiz_sessions%rowtype;
  v_earned integer; v_amount integer; v_result jsonb;
  v_day_start timestamptz := public.app_today()::timestamp at time zone 'Europe/Istanbul';
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  select * into v_session from public.verified_quiz_sessions
    where user_id = auth.uid() and client_round_id = p_client_round_id for update;
  if not found or v_session.completed_at is null
    or v_session.answered_count <> cardinality(v_session.question_ids)
  then return jsonb_build_object('amount', 0, 'verification_required', true); end if;
  if v_session.reward_result is not null then
    return v_session.reward_result || jsonb_build_object('already_claimed', true);
  end if;
  if v_session.day <> public.app_today() then
    return jsonb_build_object('amount', 0, 'verification_required', true);
  end if;
  perform 1 from public.profiles where id = auth.uid() for update;
  if not found then raise exception 'Profile missing'; end if;
  select coalesce(sum(amount), 0) into v_earned from public.coin_transactions
    where player_id = auth.uid() and reason = 'solo_round'
      and created_at >= v_day_start and created_at < v_day_start + interval '1 day';
  v_amount := least(4 + v_session.correct_count + v_session.best_streak,
    greatest(45 - v_earned, 0));
  if v_amount > 0 then
    insert into public.coin_transactions(player_id, amount, reason)
    values(auth.uid(), v_amount, 'solo_round');
  end if;
  v_result := jsonb_build_object('amount', v_amount, 'daily_cap', 45,
    'cap_reached', v_earned + v_amount >= 45, 'session_id', v_session.id);
  update public.verified_quiz_sessions set reward_result = v_result where id = v_session.id;
  return v_result;
end;
$function$;

create or replace function public.submit_verified_daily_event_result(p_client_round_id uuid)
returns boolean language plpgsql security definer
set search_path = public, pg_temp
as $function$
declare v_session public.verified_quiz_sessions%rowtype;
begin
  if auth.uid() is null then raise exception 'Authenticated user required'; end if;
  select * into v_session from public.verified_quiz_sessions
    where user_id = auth.uid() and client_round_id = p_client_round_id for update;
  if not found or not v_session.is_daily or v_session.completed_at is null
    or v_session.answered_count <> 10 or v_session.day <> public.app_today()
    or v_session.day < (select first_day from public.verified_quiz_cutover where singleton)
  then return false; end if;
  insert into public.verified_daily_event_results
    (day, user_id, correct_count, total_count, seconds, session_id)
  values(v_session.day, auth.uid(), v_session.correct_count, 10,
    greatest(1, ceil(extract(epoch from (v_session.completed_at - v_session.started_at)))::integer),
    v_session.id)
  on conflict(day, user_id) do nothing;
  return exists(select 1 from public.verified_daily_event_results
    where session_id = v_session.id and user_id = auth.uid());
end;
$function$;

-- Eski imzalar uyumlu dönüş türünü korur ama BEYANLA ödeme/kayıt yapmaz.
create or replace function public.claim_solo_reward(
  p_correct_count integer, p_total_questions integer, p_best_streak integer,
  p_client_round_id uuid
) returns jsonb language sql security definer set search_path = public, pg_temp
as $function$
  select jsonb_build_object('amount', 0, 'verification_required', true);
$function$;
create or replace function public.claim_solo_reward(
  p_correct_count integer, p_total_questions integer, p_best_streak integer
) returns jsonb language sql security definer set search_path = public, pg_temp
as $function$
  select jsonb_build_object('amount', 0, 'verification_required', true);
$function$;
create or replace function public.submit_daily_event_result(
  p_correct integer, p_total integer, p_seconds integer
) returns boolean language sql security definer set search_path = public, pg_temp
as $function$ select false; $function$;

-- Engelleme/görünürlük ve güncel pano iş kurallarını CANLI tanımdan koru.
-- Beklenen kaynak değişmişse sessizce eski gövdeyi yüklemek yerine dur.
do $board$
declare v_def text;
begin
  if to_regprocedure('public.get_verified_daily_event_board()') is null then
    select definition into v_def from public.g5g9_function_backup
      where signature = 'public.get_daily_event_board()';
    if position('public.daily_event_results' in v_def) = 0 then
      raise exception 'G9 board source drift: manual live-definition review required';
    end if;
    v_def := replace(v_def, 'public.get_daily_event_board()', 'public.get_verified_daily_event_board()');
    v_def := replace(v_def, 'public.daily_event_results', 'public.verified_daily_event_results');
    execute v_def;
  end if;
end;
$board$;
alter function public.get_verified_daily_event_board() set search_path = public, pg_temp;
create or replace function public.get_daily_event_board()
returns jsonb language sql stable security definer set search_path = public, pg_temp
as $function$ select public.get_verified_daily_event_board(); $function$;

do $permissions$
declare v_signature text;
begin
  foreach v_signature in array array[
    'get_verified_daily_question_ids()',
    'prepare_verified_solo_questions(text,integer)',
    'start_verified_quiz(uuid,uuid[],boolean,uuid)',
    'answer_verified_quiz(uuid,uuid,text)',
    'claim_verified_solo_reward(uuid)',
    'submit_verified_daily_event_result(uuid)',
    'get_verified_daily_event_board()',
    'claim_solo_reward(integer,integer,integer)',
    'claim_solo_reward(integer,integer,integer,uuid)',
    'submit_daily_event_result(integer,integer,integer)',
    'get_daily_event_board()'
  ] loop
    execute 'revoke all on function public.' || v_signature || ' from public, anon';
    execute 'grant execute on function public.' || v_signature || ' to authenticated';
  end loop;
end;
$permissions$;

commit;
