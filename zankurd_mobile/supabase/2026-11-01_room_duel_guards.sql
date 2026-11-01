-- G6/G7/G8: YALNIZ aday; canlı bağlantı/uygulama yapılmadı.
-- Dağıtımdan önce aşağıdaki imzaların pg_get_functiondef çıktıları alınmalı,
-- bu sarmalayıcılarla diff ve BEGIN/ROLLBACK duman testi yapılmalıdır.
-- Eski göç gövdelerini kopyalamaz: tam güncel tanım işlem içinde saklanır.
-- Önce istemci dağıtılır; eski sunucu fallback'i korunur. Sonra bu göç.
begin;
create table if not exists public.room_duel_guards_20261101_backup (
  signature text primary key,
  definition text not null
);
alter table public.room_duel_guards_20261101_backup enable row level security;
revoke all on public.room_duel_guards_20261101_backup from public, anon, authenticated;

-- Çekirdek kopyalar güncel üyelik/ödül/kalabalık oda kurallarını korur.
do $migration$
declare
  item record;
  source text;
  target text;
begin
  for item in select * from (values
    ('join_room_by_code', 'text'),
    ('join_room_by_code_v2', 'text'),
    ('get_room_questions', 'uuid'),
    ('answer_async_duel', 'uuid,integer,text,integer'),
    ('start_async_duel', 'text'),
    ('create_async_duel_challenge', 'text,uuid'),
    ('accept_async_duel_challenge', 'text'),
    ('resume_my_async_duel', 'uuid')
  ) as funcs(name, args) loop
    if not exists (select 1 from public.room_duel_guards_20261101_backup
      where signature = item.name || '(' || item.args || ')') then
      source := pg_get_functiondef(to_regprocedure('public.' || item.name || '(' || item.args || ')'));
      if source is null then raise exception 'Required live function missing: %', item.name; end if;
      if item.name = 'answer_async_duel' and (
          position('v_elapsed_ms > v_max_ms + 5000' in source) = 0
          or position('v_is_correct := false' in source) = 0
          or position('async_duel_question_starts' in source) = 0) then
        raise exception 'Duel timing definition changed; review live diff first';
      end if;
      insert into public.room_duel_guards_20261101_backup values
        (item.name || '(' || item.args || ')', source);
      target := replace(source, 'FUNCTION public.' || item.name || '(',
        'FUNCTION public._guard_20261101_' || item.name || '(');
      if target = source then raise exception 'Unrecognized function header: %', item.name; end if;
      if item.name = 'join_room_by_code_v2' then
        if position('public.join_room_by_code(p_code)' in target) = 0 then
          raise exception 'Join v2 definition changed; review live diff first';
        end if;
        target := replace(target, 'public.join_room_by_code(p_code)',
          'public._guard_20261101_join_room_by_code(p_code)');
      end if;
      execute target;
      execute format('alter function public._guard_20261101_%I(%s) set search_path = public, pg_temp', item.name, item.args);
      execute format('revoke all on function public._guard_20261101_%I(%s) from public, anon, authenticated', item.name, item.args);
    end if;
  end loop;
end;
$migration$;

-- G6: iki dış imza AYNI sayaç ve seri kilit üzerinden geçer.
-- Hatalı kod v2 çekirdeğinde EXCEPTION alt işlemi dışında JSON döndürülür;
-- transaction başarılı kaldığından room_code_misses kaydı rollback olmaz.
create or replace function public.join_room_by_code_v2(p_code text)
returns json language plpgsql security definer set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 61101));
  return public._guard_20261101_join_room_by_code_v2(p_code);
end;
$function$;
create or replace function public.join_room_by_code(p_code text)
returns json language sql security definer set search_path = public, pg_temp
as $function$
  select public.join_room_by_code_v2(p_code);
$function$;
revoke all on function public.join_room_by_code(text), public.join_room_by_code_v2(text) from public, anon;
grant execute on function public.join_room_by_code(text), public.join_room_by_code_v2(text) to authenticated;

-- G7: yetkiyi güncel çekirdek denetler; sıra korunur, gelecek içerik yoktur.
create or replace function public.get_room_questions(p_room_id uuid)
returns setof jsonb language plpgsql security definer set search_path = public, pg_temp
as $function$
declare
  row_data jsonb;
  room_state public.rooms%rowtype;
  question_position integer;
  question_started_at timestamptz;
begin
  select * into room_state from public.rooms where id = p_room_id;
  for row_data in select * from public._guard_20261101_get_room_questions(p_room_id) loop
    select rq.question_index, rq.started_at into question_position, question_started_at from public.room_questions rq
      where rq.room_id = p_room_id and rq.question_id = (row_data->>'id')::uuid;
    if room_state.status = 'finished'
       or question_position < coalesce(room_state.current_question_index, 0)
       or (room_state.status = 'active'
           and question_position = coalesce(room_state.current_question_index, 0)
           and question_started_at is not null) then
      return next row_data;
    else
      return next jsonb_build_object('id', row_data->>'id',
        'index', question_position, 'prompt', '', 'content_hidden', true);
    end if;
  end loop;
end;
$function$;
revoke all on function public.get_room_questions(uuid) from public, anon;
grant execute on function public.get_room_questions(uuid) to authenticated, service_role;

-- G8: tüm başlangıç/devam yollarında yalnız kimlik/sıra döner.
-- İçerik ve sunucu başlangıcı tek sunum işlemiyle açılır.
create or replace function public._guard_20261101_hide_duel_content(p_payload jsonb)
returns jsonb language sql set search_path = public, pg_temp
as $function$
  select jsonb_set(p_payload, '{questions}', coalesce((
    select jsonb_agg(jsonb_build_object('id', q->>'id',
      'index', ord - 1, 'prompt', '', 'content_hidden', true) order by ord)
    from jsonb_array_elements(p_payload->'questions') with ordinality as rows(q, ord)
  ), '[]'::jsonb));
$function$;
revoke all on function public._guard_20261101_hide_duel_content(jsonb) from public, anon, authenticated;

create or replace function public.start_async_duel(p_category text default null)
returns jsonb language sql security definer set search_path = public, pg_temp
as $function$
  select public._guard_20261101_hide_duel_content(public._guard_20261101_start_async_duel(p_category));
$function$;
revoke all on function public.start_async_duel(text) from public, anon;
grant execute on function public.start_async_duel(text) to authenticated;

create or replace function public.create_async_duel_challenge(p_category text default null, p_friend_id uuid default null)
returns jsonb language sql security definer set search_path = public, pg_temp
as $function$
  select public._guard_20261101_hide_duel_content(public._guard_20261101_create_async_duel_challenge(p_category, p_friend_id));
$function$;
revoke all on function public.create_async_duel_challenge(text,uuid) from public, anon;
grant execute on function public.create_async_duel_challenge(text,uuid) to authenticated;

create or replace function public.accept_async_duel_challenge(p_code text)
returns jsonb language sql security definer set search_path = public, pg_temp
as $function$
  select public._guard_20261101_hide_duel_content(public._guard_20261101_accept_async_duel_challenge(p_code));
$function$;
revoke all on function public.accept_async_duel_challenge(text) from public, anon;
grant execute on function public.accept_async_duel_challenge(text) to authenticated;

create or replace function public.resume_my_async_duel(p_duel_id uuid)
returns jsonb language sql security definer set search_path = public, pg_temp
as $function$
  select public._guard_20261101_hide_duel_content(public._guard_20261101_resume_my_async_duel(p_duel_id));
$function$;
revoke all on function public.resume_my_async_duel(uuid) from public, anon;
grant execute on function public.resume_my_async_duel(uuid) to authenticated;

create or replace function public.present_async_duel_question_v2(p_duel_id uuid, p_question_index integer)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $function$
declare
  result jsonb;
  question jsonb;
begin
  -- Mevcut RPC kimlik, üyelik, süre, sıra kontrolü yapar ve idempotent
  -- başlangıcı kaydeder. Başarısızsa aşağıdaki içerik sorgusu çalışmaz.
  result := public.present_async_duel_question(p_duel_id, p_question_index);
  select jsonb_build_object('id', q.id, 'prompt', q.prompt,
    'category_name', c.name, 'option_a', q.option_a, 'option_b', q.option_b,
    'option_c', q.option_c, 'option_d', q.option_d,
    'question_type', q.question_type, 'image_url', q.image_url,
    'difficulty', q.difficulty) into question
  from public.async_duels d
  join public.questions q on q.id = d.question_ids[p_question_index + 1]
  left join public.categories c on c.id = q.category_id
  where d.id = p_duel_id;
  if question is null then raise exception 'Question unavailable'; end if;
  return result || jsonb_build_object('question', question);
end;
$function$;
revoke all on function public.present_async_duel_question_v2(uuid, integer) from public, anon;
grant execute on function public.present_async_duel_question_v2(uuid, integer) to authenticated;

create or replace function public.answer_async_duel(p_duel_id uuid, p_question_index integer, p_choice text, p_response_ms integer)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  -- TIMEOUT: içeriği görmeden terk edilen sorular da yanlış kaydedilebilir.
  -- Normal cevapta kayıt yoksa doğru/puan üretilmeden reddedilir.
  if p_choice is distinct from 'TIMEOUT' and not exists (
    select 1 from public.async_duel_question_starts st
    where st.duel_id = p_duel_id and st.player_id = auth.uid()
      and st.question_index = p_question_index
  ) then raise exception 'Question not presented'; end if;
  return public._guard_20261101_answer_async_duel(p_duel_id, p_question_index, p_choice, p_response_ms);
end;
$function$;
revoke all on function public.answer_async_duel(uuid, integer, text, integer) from public, anon;
grant execute on function public.answer_async_duel(uuid, integer, text, integer) to authenticated;
commit;
