-- Oda kodu 6 rakam + çok kategorili/Karışık oda + kolaylaşan sorular (2026-10-18).
--
-- Neden (test kullanıcılarının geri bildirimi):
--  1. 'ZK-' + 10 onaltılık karakter sesli söylenemiyor; 6 rakamlı kod
--     ("482 913") söylenir, hatırlanır. Eski odalar kodlarını korur, eski
--     'ZK-XXXXXXXXXX' kodu katılımda hâlâ çalışır.
--     1 milyonluk uzayda çakışma olabileceğinden benzersizlik KÜRESEL değil
--     yalnız AÇIK odalar (lobby/active/reveal) arasındadır: rooms_code_key
--     düşer, yerine kısmi benzersiz dizin gelir. join_room_by_code zaten
--     yalnız 'lobby' odayı çözer; en yeniyi seçer, biten bir odanın aynı
--     kodu katılımı asla ele geçiremez.
--  2. Özel odada tek kategori yerine Karışık ya da çoklu seçim:
--     rooms.category_ids uuid[]  (NULL + category_id NULL = Karışık;
--     category_id dolu = tek kategori [eski anlam]; category_ids dolu =
--     çoklu). Yeni RPC create_online_room_v2(text[], ...). ESKİ 5
--     parametreli create_online_room AYNEN çalışır (ince sarmalayıcı):
--     mağazadaki sürümler bozulmaz. İki aşırı yükleme YOK (PostgREST
--     adlandırılmış çağrıda belirsizlik hatası verirdi); ad farklıdır.
--     ESKİ RPC eski 'ZK-'+10 onaltılık kodu üretmeye DEVAM EDER (mağaza
--     sürümleri yalnız onu katılımda kabul eder); yalnız v2 6 rakam üretir.
--     Gövde create_online_room_impl'dedir (istemciye kapalı).
--     Kategori etiketi (category_name) için public.room_category_label:
--     Karışık -> 'Tevlihev', çoklu -> adlar ', ' ile.
--  3. Sorular zor bulundu: oda ve 1v1 düello soru seçimi eskiden düz
--     random() idi (canlı havuz ~%55 kolay, %20 orta, %25 zor).
--     public.weighted_question_pick ~%60 kolay (1-2), ~%30 orta (3), ~%10 zor
--     (4-5) seçer, görülmemişleri tercih eder, ilk soruyu kolay yapar, bant
--     kısaysa kalanı başka bantlardan tamamlar. start_room_game
--     (oda + hızlı eşleşme aynı fonksiyonu kullanır), create_async_duel_challenge
--     ve start_async_duel bunu çağırır; mevcut süzgeçler/görülmüş soru
--     kaçınması/kalabalık oda mantığı aynen korundu.
--
-- Gövdeler 2026-10-18'de CANLI pg_get_functiondef çıktısından türetildi
-- (build/oda_kod_diff.txt: canlı ↔ yeni fark). Değişen fonksiyonlar:
-- create_online_room (sarmalayıcı), create_online_room_v2 (yeni),
-- join_room_by_code, start_room_game, create_async_duel_challenge,
-- start_async_duel, get_my_resumable_room, get_room_result_payload,
-- join_matchmaking (son üçü yalnız kategori etiketi).
-- Uygulama: supabase db query --linked -f supabase/2026-10-18_oda_kod_kategori.sql
begin;

alter table public.rooms add column if not exists category_ids uuid[];

-- Açık odalar arasında benzersiz kod (küresel kısıt yerine).
create unique index if not exists rooms_open_upper_code_uidx
  on public.rooms (upper(code))
  where status in ('lobby', 'active', 'reveal');

alter table public.rooms drop constraint if exists rooms_code_key;

create or replace function public.room_category_label(p_category_ids uuid[], p_name text)
returns text
language sql
stable
set search_path to 'public'
as $f$
  select case
    when p_category_ids is not null and cardinality(p_category_ids) > 0 then
      (select string_agg(c.name, ', ' order by c.name)
       from public.categories c where c.id = any(p_category_ids))
    when p_name is not null then p_name
    else 'Tevlihev'
  end;
$f$;

create or replace function public.weighted_question_pick(
  p_candidate_ids uuid[],
  p_seen_ids uuid[],
  p_count integer
)
returns uuid[]
language sql
volatile
set search_path to 'public'
as $f$
  with q as (
    select
      x.id,
      (x.id = any(coalesce(p_seen_ids, '{}'::uuid[]))) as seen,
      case
        when d.difficulty <= 2 then 1
        when d.difficulty >= 4 then 3
        else 2
      end as band,
      random() as rnd
    from unnest(coalesce(p_candidate_ids, '{}'::uuid[])) as x(id)
    join public.questions d on d.id = x.id
  ),
  quota as (
    select
      round(p_count * 0.6)::integer as easy,
      round(p_count * 0.1)::integer as hard
  ),
  ranked as (
    select q.*, row_number() over (partition by q.band order by q.seen, q.rnd) as br
    from q
  ),
  prim as (
    select r.*
    from ranked r, quota
    where r.br <= case r.band
      when 1 then quota.easy
      when 3 then quota.hard
      else p_count - quota.easy - quota.hard
    end
  ),
  fill as (
    select r.*
    from ranked r
    where r.id not in (select id from prim)
    order by r.band, r.seen, r.rnd
    limit greatest(p_count - (select count(*) from prim), 0)
  ),
  chosen as (
    select * from prim
    union all
    select * from fill
  ),
  first_pick as (
    select id from chosen where band = 1 order by rnd limit 1
  ),
  ordered as (
    select
      c.id,
      row_number() over (
        order by coalesce(c.id = (select id from first_pick), false) desc, c.rnd
      ) as ord
    from chosen c
  )
  select array_agg(id order by ord) from ordered;
$f$;

revoke all on function public.room_category_label(uuid[], text) from public, anon;
grant execute on function public.room_category_label(uuid[], text) to authenticated, service_role;
revoke all on function public.weighted_question_pick(uuid[], uuid[], integer) from public, anon, authenticated;
grant execute on function public.weighted_question_pick(uuid[], uuid[], integer) to service_role;

CREATE OR REPLACE FUNCTION public.create_online_room_impl(p_category_names text[], p_seconds_per_question integer, p_question_count integer, p_entry_fee integer, p_max_players integer, p_legacy_code boolean)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_id uuid;
  v_category_ids uuid[];
  v_category_name text;
  v_wanted text[];
  v_found_ids uuid[];
  v_found_names text[];
  v_existing record;
  v_room_id uuid;
  v_room_code text;
  v_attempt integer := 0;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_seconds_per_question is null
     or p_seconds_per_question not in (10, 15, 20, 30, 45, 60) then
    raise exception 'Unsupported seconds per question';
  end if;

  if p_question_count is null
     or p_question_count not in (5, 10, 15) then
    raise exception 'Unsupported question count';
  end if;

  if p_entry_fee is null
     or p_entry_fee not in (0, 25, 50, 100) then
    raise exception 'Unsupported entry fee';
  end if;

  -- Kapasite: 2 = ikili özel oda, 4..50 = kalabalık oda.
  if p_max_players is null
     or p_max_players not in (2, 4, 8, 16, 30, 50) then
    raise exception 'Unsupported max players';
  end if;

  -- Kategori seçimi (2026-10-18): NULL ya da boş dizi = Karışık (hepsi);
  -- tek ad = eski davranış (category_id dolu); iki ya da daha çok ad =
  -- category_ids dolu, category_id NULL. Boş/NULL eleman reddedilir.
  if p_category_names is null or cardinality(p_category_names) = 0 then
    v_category_name := 'Tevlihev';
  else
    if cardinality(p_category_names) > 12
       or exists (
         select 1 from unnest(p_category_names) n
         where nullif(btrim(n), '') is null
       ) then
      raise exception 'Category is not available';
    end if;

    select array_agg(distinct upper(btrim(n))) into v_wanted
    from unnest(p_category_names) n;

    select array_agg(c.id order by c.name), array_agg(c.name order by c.name)
    into v_found_ids, v_found_names
    from public.categories c
    where upper(c.name) = any(v_wanted)
      and c.is_active = true;

    if v_found_ids is null
       or cardinality(v_found_ids) <> cardinality(v_wanted) then
      raise exception 'Category is not available';
    end if;

    if cardinality(v_found_ids) = 1 then
      v_category_id := v_found_ids[1];
    else
      v_category_ids := v_found_ids;
    end if;
    v_category_name := array_to_string(v_found_names, ', ');
  end if;

  -- spend_coins ve buy_streak_freeze ile aynı profil satır kilidini al
  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform 1 from public.profiles where id = v_uid for update;

  -- Bakiye kontrolü kilit alındıktan sonra yapılır (çift harcama yarış durumu önlemi)
  if p_entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < p_entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  -- Aktif oda varsa snapshot'ı dön
  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    r.is_custom,
    r.max_players,
    public.room_category_label(r.category_ids, c.name) as category_name
  into v_existing
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id and rp.player_id = v_uid
   and rp.left_at is null
  left join public.categories c on c.id = r.category_id
  where r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    delete from public.matchmaking_queue mq
    where mq.player_id = v_uid
      and mq.room_id is null;

    return json_build_object(
      'room_id', v_existing.id,
      'code', v_existing.code,
      'host_id', v_existing.host_id,
      'category_name', v_existing.category_name,
      'question_count', v_existing.question_count,
      'seconds_per_question', v_existing.seconds_per_question,
      'entry_fee', v_existing.entry_fee,
      'max_players', v_existing.max_players,
      'is_custom', v_existing.is_custom,
      'status', v_existing.status
    );
  end if;

  loop
    v_attempt := v_attempt + 1;
    -- 6 haneli rakam kodu (ilk hane 1-9): sesli söylenir. Benzersizlik
    -- yalnız AÇIK odalar arasındadır (rooms_open_upper_code_uidx).
    if p_legacy_code then
      -- Mağazadaki eski istemciler yalnız ZK-+10 onaltılık kodu katılımda
      -- kabul eder: eski 5 parametreli RPC bunu AYNEN üretmeye devam eder.
      v_room_code := 'ZK-' || upper(
        substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
      );
    else
      v_room_code := (1 + floor(random() * 9))::integer::text
        || lpad(floor(random() * 100000)::integer::text, 5, '0');
    end if;

    begin
      insert into public.rooms (
        code,
        host_id,
        category_id,
        category_ids,
        question_count,
        seconds_per_question,
        entry_fee,
        is_custom,
        max_players,
        status
      ) values (
        v_room_code,
        v_uid,
        v_category_id,
        v_category_ids,
        p_question_count,
        p_seconds_per_question,
        p_entry_fee,
        true,
        p_max_players,
        'lobby'
      ) returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 20 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room_id, v_uid, true);

  if p_entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -p_entry_fee, 'room_entry_fee');
  end if;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room_id,
    'code', v_room_code,
    'host_id', v_uid,
    'category_name', v_category_name,
    'question_count', p_question_count,
    'seconds_per_question', p_seconds_per_question,
    'entry_fee', p_entry_fee,
    'max_players', p_max_players,
    'is_custom', true,
    'status', 'lobby'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_online_room_v2(p_category_names text[], p_seconds_per_question integer, p_question_count integer DEFAULT 10, p_entry_fee integer DEFAULT 0, p_max_players integer DEFAULT 2)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Yeni istemci: 6 rakamlı kod; NULL/boş dizi = Karışık.
  return public.create_online_room_impl(
    p_category_names, p_seconds_per_question, p_question_count,
    p_entry_fee, p_max_players, false
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_online_room(p_category_name text, p_seconds_per_question integer, p_question_count integer DEFAULT 10, p_entry_fee integer DEFAULT 0, p_max_players integer DEFAULT 2)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Eski istemci (mağazadaki sürümler) 5 parametreli imzayı çağırır: tek ad
  -- zorunlu, anlamı değişmedi. Asıl iş create_online_room_impl'dedir (eski 'ZK-' kod biçimi).
  if nullif(btrim(coalesce(p_category_name, '')), '') is null then
    raise exception 'Category is not available';
  end if;
  return public.create_online_room_impl(
    array[p_category_name],
    p_seconds_per_question,
    p_question_count,
    p_entry_fee,
    p_max_players,
    true
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_room_by_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_existing_room_id uuid;
  v_player_count integer;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform 1 from public.profiles where id = v_uid for update;

  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and rp.left_at is null
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    r.is_custom,
    r.max_players,
    public.room_category_label(r.category_ids, c.name) as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where r.status = 'lobby'
    and (
      upper(r.code) = upper(btrim(p_code))
      or (
        regexp_replace(btrim(p_code), '[\s-]', '', 'g') ~ '^[0-9]{6}$'
        and r.code = regexp_replace(btrim(p_code), '[\s-]', '', 'g')
      )
    )
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  if v_existing_room_id is not null
     and v_existing_room_id <> v_room.id then
    raise exception 'Player is already in another live room';
  end if;

  -- Bakiye kontrolü kilit alındıktan sonra yapılır
  if v_room.entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < v_room.entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  if exists (
    select 1
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.player_id = v_uid
  ) then
    return json_build_object(
      'room_id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'entry_fee', v_room.entry_fee,
      'max_players', v_room.max_players,
      'is_custom', v_room.is_custom,
      'category_name', v_room.category_name
    );
  end if;

  -- Kapasite kontrolü: kalabalık odada aktif oyuncu sayısı

  -- Engelleme (2026-10-02 M5): oda sahibi ya da odadaki biriyle aramızda
  -- HER İKİ YÖNDE engel varsa katılım reddedilir. Mesaj bilerek mevcut
  -- "bulunamadı" mesajıdır: engelleyen kişinin odasını arayan bir kullanıcı
  -- engellendiğini öğrenmemeli; istemci bunu zaten `notFound`a eşler.
  if exists (
    select 1
    from public.blocked_users b
    where (b.blocker_id = v_uid
           and (b.blocked_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocked_id)))
       or (b.blocked_id = v_uid
           and (b.blocker_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocker_id)))
  ) then
    raise exception 'Room not found or already started';
  end if;
  if v_room.is_custom and v_room.max_players > 2 then
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.left_at is null;

    if v_player_count >= v_room.max_players then
      raise exception 'Room is full';
    end if;
  else
    -- 2 kişilik oda kuralı
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id;

    if v_player_count >= 2 then
      raise exception 'Room is full';
    end if;
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  if v_room.entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -v_room.entry_fee, 'room_entry_fee');
  end if;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'entry_fee', v_room.entry_fee,
    'max_players', v_room.max_players,
    'is_custom', v_room.is_custom,
    'category_name', v_room.category_name
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_resumable_room()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_answers jsonb := '[]'::jsonb;
  v_pending_answer jsonb := null;
  v_own_score integer := 0;
  v_own_streak integer := 0;
  v_correct_count integer := 0;
  v_wrong_count integer := 0;
  v_best_streak integer := 0;
  v_server_now timestamp with time zone;
  v_current_started_at timestamp with time zone;
  v_current_deadline timestamp with time zone;
  v_remaining_ms integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    coalesce(r.current_question_index, 0) as current_question_index,
    r.is_custom,
    r.max_players,
    public.room_category_label(r.category_ids, c.name) as category_name
  into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  left join public.categories c on c.id = r.category_id
  where rp.player_id = v_uid
    -- Oyundan ayrılan/düşen oyuncu odaya geri çağrılmaz.
    and rp.left_at is null
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for share of r;

  if not found then
    return null;
  end if;

  v_server_now := clock_timestamp();

  -- Sonuç alanları yalnız açıkça reveal edilmiş (ve eski veri için geçmiş
  -- indekste kalmış) sorulardan üretilir. Böylece hem cevap listesi hem de
  -- skor/sayaç/seri aynı sızıntısız veri kümesine dayanır.
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'question_index', rq.question_index,
          'question_id', rq.question_id,
          'selected_option', pa.selected_option,
          'is_correct', pa.is_correct,
          'points_awarded', pa.points_awarded,
          'response_ms', pa.response_ms,
          'correct_option', q.correct_option,
          'explanation', q.explanation,
          'explanation_ku', q.explanation_ku,
          'explanation_tr', q.explanation_tr
        ) order by rq.question_index
      ),
      '[]'::jsonb
    ),
    coalesce(sum(pa.points_awarded), 0)::integer,
    count(*) filter (where pa.is_correct)::integer,
    count(*) filter (where not pa.is_correct)::integer
  into v_answers, v_own_score, v_correct_count, v_wrong_count
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  join public.questions q on q.id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid
    and (
      rq.question_index < v_room.current_question_index
      or rq.revealed_at is not null
    );

  select count(*)::integer
  into v_own_streak
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid
    and pa.is_correct
    and (
      rq.question_index < v_room.current_question_index
      or rq.revealed_at is not null
    )
    and rq.question_index > coalesce((
      select max(wrong_rq.question_index)
      from public.player_answers wrong_answer
      join public.room_questions wrong_rq
        on wrong_rq.room_id = wrong_answer.room_id
        and wrong_rq.question_id = wrong_answer.question_id
      where wrong_answer.room_id = v_room.id
        and wrong_answer.player_id = v_uid
        and not wrong_answer.is_correct
        and (
          wrong_rq.question_index < v_room.current_question_index
          or wrong_rq.revealed_at is not null
        )
    ), -1);

  -- Soru sırasındaki reveal edilmiş kesintisiz doğru gruplarının en büyüğü.
  select coalesce(max(streaks.streak_length), 0)::integer
  into v_best_streak
  from (
    select count(*)::integer as streak_length
    from (
      select
        pa.is_correct,
        sum(case when pa.is_correct then 0 else 1 end) over (
          order by rq.question_index
        ) as wrong_group
      from public.player_answers pa
      join public.room_questions rq
        on rq.room_id = pa.room_id and rq.question_id = pa.question_id
      where pa.room_id = v_room.id
        and pa.player_id = v_uid
        and (
          rq.question_index < v_room.current_question_index
          or rq.revealed_at is not null
        )
    ) ordered_answers
    where ordered_answers.is_correct
    group by ordered_answers.wrong_group
  ) streaks;

  -- Mevcut soru için gönderilmiş fakat reveal edilmemiş cevap yalnız güvenli
  -- seçim/zaman alanlarıyla ayrı taşınır.
  select jsonb_build_object(
    'question_index', pending_rq.question_index,
    'question_id', pending.question_id,
    'selected_option', pending.selected_option,
    'response_ms', pending.response_ms
  )
  into v_pending_answer
  from public.player_answers pending
  join public.room_questions pending_rq
    on pending_rq.room_id = pending.room_id
    and pending_rq.question_id = pending.question_id
  where pending.room_id = v_room.id
    and pending.player_id = v_uid
    and pending_rq.question_index = v_room.current_question_index
    and pending_rq.revealed_at is null
  limit 1;

  select rq.started_at
  into v_current_started_at
  from public.room_questions rq
  where rq.room_id = v_room.id
    and rq.question_index = v_room.current_question_index;

  if v_current_started_at is not null then
    v_current_deadline := v_current_started_at + make_interval(
      secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
    );
    v_remaining_ms := least(
      2147483647::bigint,
      greatest(
        0::bigint,
        floor(
          extract(epoch from (v_current_deadline - v_server_now)) * 1000
        )::bigint
      )
    )::integer;
  end if;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'is_custom', v_room.is_custom,
    'max_players', v_room.max_players,
    'status', v_room.status,
    'category_name', v_room.category_name,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'current_question_index', v_room.current_question_index,
    'own_score', v_own_score,
    'own_streak', v_own_streak,
    'correct_count', v_correct_count,
    'wrong_count', v_wrong_count,
    'best_streak', v_best_streak,
    'answers', v_answers,
    'pending_answer', v_pending_answer,
    'server_now', v_server_now,
    'current_question_started_at', v_current_started_at,
    'current_question_deadline', v_current_deadline,
    'current_question_remaining_ms', v_remaining_ms
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_room_result_payload(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_players jsonb;
  v_question_ids jsonb;
  v_answers jsonb;
  v_winner_id uuid;
  v_crowd boolean := false;
  v_saved_result record;
  v_saved_found boolean := false;
  v_live_found boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select
    saved_result.room_id,
    saved_result.payload,
    saved_result.finished_at,
    saved_result.room_created_at
  into v_saved_result
  from public.room_result_snapshots saved_result
  join public.room_players saved_member
    on saved_member.room_id = saved_result.room_id
    and saved_member.player_id = saved_result.player_id
  where saved_result.player_id = v_uid
    and (p_room_id is null or saved_result.room_id = p_room_id)
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = saved_result.room_id
        and receipt.player_id = v_uid
    )
  order by
    saved_result.finished_at desc,
    saved_result.room_created_at desc,
    saved_result.room_id desc
  limit 1;
  v_saved_found := found;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    r.current_question_index,
    r.ended_reason,
    r.forfeited_by,
    r.finished_at,
    r.created_at,
    r.is_custom,
    r.max_players,
    public.room_category_label(r.category_ids, c.name) as category_name
  into v_room
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_uid
  left join public.categories c on c.id = r.category_id
  where r.status = 'finished'
    and (p_room_id is null or r.id = p_room_id)
    and r.ended_reason = 'completed'
    and r.forfeited_by is null
    and r.finished_at is not null
    and r.question_count > 0
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = r.id
        and receipt.player_id = v_uid
    )
    and (
      (
        r.is_custom and r.max_players > 2
        -- Ayrılan/düşen oyuncu da biten odanın sonucunu görür (2026-10-16):
        -- `left: true`, sırasız ve havuz payı olmadan gelir. Makbuz
        -- (acknowledge_room_result) bir kez verildikten sonra bekleyen
        -- sonuç olarak tekrar sunulmaz.
        and public.crowd_room_result_complete(r.id)
      )
      or (
    not (r.is_custom and r.max_players > 2)
    and coalesce(r.current_question_index, -1) = r.question_count
    and exists (
      select 1
      from public.room_players exact_players
      where exact_players.room_id = r.id
      having count(*) = 2
    )
    and exists (
      select 1
      from public.room_questions rq
      where rq.room_id = r.id
      having count(*) = r.question_count
        and count(distinct rq.question_index) = r.question_count
        and min(rq.question_index) = 0
        and max(rq.question_index) = r.question_count - 1
        and bool_and(rq.revealed_at is not null)
    )
    and exists (
      select 1
      from public.player_answers pa
      join public.room_questions answered_question
        on answered_question.room_id = pa.room_id
        and answered_question.question_id = pa.question_id
      join public.room_players answering_player
        on answering_player.room_id = pa.room_id
        and answering_player.player_id = pa.player_id
      where pa.room_id = r.id
      having count(*) = r.question_count * 2
    )
    and not exists (
      select 1
      from public.room_players member
      where member.room_id = r.id
        and (
          select count(*)
          from public.player_answers own_answer
          join public.room_questions own_question
            on own_question.room_id = own_answer.room_id
            and own_question.question_id = own_answer.question_id
          where own_answer.room_id = member.room_id
            and own_answer.player_id = member.player_id
        ) <> r.question_count
    )
    and not exists (
      select 1
      from public.room_players scored_player
      where scored_player.room_id = r.id
        and scored_player.score <> (
          select coalesce(sum(scored_answer.points_awarded), 0)::integer
          from public.player_answers scored_answer
          where scored_answer.room_id = scored_player.room_id
            and scored_answer.player_id = scored_player.player_id
        )
    )
      )
    )
  order by r.finished_at desc, r.created_at desc, r.id desc
  limit 1
  for share of r;
  v_live_found := found;

  if not v_live_found and not v_saved_found then
    return null;
  end if;

  if v_saved_found and (
    not v_live_found
    or row(
      v_saved_result.finished_at,
      v_saved_result.room_created_at,
      v_saved_result.room_id
    ) > row(v_room.finished_at, v_room.created_at, v_room.id)
  ) then
    return v_saved_result.payload;
  end if;

  v_crowd := v_room.is_custom and v_room.max_players > 2;

  if v_crowd then
    -- Kalabalık oda: skora göre sıralı, eşitlikte aynı rank'lı oyuncu listesi.
    v_players := public.room_result_players(v_room.id, null);
  else
  select jsonb_agg(
    jsonb_build_object(
      'player_id', rp.player_id,
      'display_name', coalesce(nullif(trim(p.display_name), ''), 'Hevrik'),
      'final_score', rp.score,
      'final_streak', rp.streak
    ) order by rp.joined_at, rp.player_id
  )
  into v_players
  from public.room_players rp
  join public.profiles p on p.id = rp.player_id
  where rp.room_id = v_room.id;
  end if;

  select jsonb_agg(rq.question_id order by rq.question_index)
  into v_question_ids
  from public.room_questions rq
  where rq.room_id = v_room.id;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', rq.question_id,
      'question_index', rq.question_index,
      'selected_option', pa.selected_option,
      'correct_option', q.correct_option,
      'is_correct', pa.is_correct,
      'points_awarded', pa.points_awarded,
      'response_ms', pa.response_ms,
      'explanation', q.explanation,
      'explanation_ku', q.explanation_ku,
      'explanation_tr', q.explanation_tr
    ) order by rq.question_index
  )
  into v_answers
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  join public.questions q on q.id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid;

  if v_crowd then
    v_winner_id := public.room_result_winner(v_room.id, null);
  else
  select case
    when min(rp.score) = max(rp.score) then null
    else (array_agg(rp.player_id order by rp.score desc, rp.player_id))[1]
  end
  into v_winner_id
  from public.room_players rp
  where rp.room_id = v_room.id;
  end if;

  return json_build_object(
    'room', json_build_object(
      'id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'category_name', v_room.category_name,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'status', 'finished',
      'current_question_index', v_room.current_question_index,
      'is_custom', v_room.is_custom,
      'max_players', v_room.max_players
    ),
    'own_player_id', v_uid,
    'players', v_players,
    'question_ids', v_question_ids,
    'answers', coalesce(v_answers, '[]'::jsonb),
    'winner_id', v_winner_id,
    'ended_reason', v_room.ended_reason,
    'forfeited_by', v_room.forfeited_by,
    'finished_at', v_room.finished_at
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_matchmaking(p_category_name text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_opponent uuid;
  v_room_id uuid;
  v_room_code text;
  v_queue_room_id uuid;
  v_category_id uuid;
  v_category_name text;
  v_opponent_name text;
  v_snapshot json;
  v_start json;
  v_attempt integer;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));

  -- Aynı oyuncunun ağ tekrarı/çift dokunuş çağrılarını transaction boyunca
  -- sırala. Rakibin kuyruk satırı ayrıca aşağıda `FOR UPDATE` ile kilitlenir.
  perform pg_advisory_xact_lock(hashtextextended(v_player_id::text, 0));

  -- Önce mevcut canlı üyelik: başarılı ilk çağrının cevabı kaybolduysa yeni
  -- oda üretmek yerine aynı sunucu snapshot'ını döndür.
  select json_build_object(
    'status', 'matched',
    'room_id', r.id,
    'code', r.code,
    'host_id', r.host_id,
    'category_name', public.room_category_label(r.category_ids, c.name),
    'question_count', r.question_count,
    'seconds_per_question', coalesce(r.seconds_per_question, 20),
    'opponent_name', coalesce(opponent.display_name, 'Hevrik')
  )
  into v_snapshot
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_player_id
      and mine.left_at is null
  left join public.categories c on c.id = r.category_id
  left join lateral (
    select p.display_name
    from public.room_players other
    join public.profiles p on p.id = other.player_id
    where other.room_id = r.id
      and other.player_id <> v_player_id
    order by other.joined_at
    limit 1
  ) opponent on true
  where r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    return v_snapshot;
  end if;

  -- "Rastgele" gerçek bir kategori değil, bütün hızlı eşleşme çağrılarının
  -- buluştuğu sanal kuyruktur. Gerçek kategori ancak iki oyuncu eşleşince
  -- aşağıda bir kez seçilir; aksi hâlde her istemcinin ayrı kategori çekmesi
  -- oyuncu havuzunu parçalar.
  if upper(trim(coalesce(p_category_name, ''))) = 'RASTGELE' then
    v_category_name := 'Rastgele';
  else
    select c.id, c.name
    into v_category_id, v_category_name
    from public.categories c
    where upper(c.name) = upper(trim(p_category_name))
      and c.is_active = true
    limit 1;
  end if;

  if v_category_name is null then
    raise exception 'Category is not available';
  end if;

  -- Farklı iki oyuncunun ilk çağrısı aynı anda geldiğinde ikisinin de
  -- birbirini görmeden ayrı waiting satırı açmasını önler. Bu kilit kendi
  -- queue satırından ÖNCE alınır; ters sıra cancel/join deadlock'u üretirdi.
  perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));

  -- Rakip bu satırı eşleştirme anında kilitlediyse burada beklenir. Kilit
  -- açıldığında `room_id` yeniden değerlendirilir; eşleşmiş satır silinmez.
  select mq.room_id into v_queue_room_id
  from public.matchmaking_queue mq
  where mq.player_id = v_player_id
  for update;

  if found and v_queue_room_id is not null then
    select json_build_object(
      'status', 'matched',
      'room_id', r.id,
      'code', r.code,
      'host_id', r.host_id,
      'category_name', public.room_category_label(r.category_ids, c.name),
      'question_count', r.question_count,
      'seconds_per_question', coalesce(r.seconds_per_question, 20),
      'opponent_name', coalesce(opponent.display_name, 'Hevrik')
    )
    into v_snapshot
    from public.rooms r
    join public.room_players mine
      on mine.room_id = r.id and mine.player_id = v_player_id
      and mine.left_at is null
    left join public.categories c on c.id = r.category_id
    left join lateral (
      select p.display_name
      from public.room_players other
      join public.profiles p on p.id = other.player_id
      where other.room_id = r.id
        and other.player_id <> v_player_id
      order by other.joined_at
      limit 1
    ) opponent on true
    where r.id = v_queue_room_id
      and r.status in ('lobby', 'active');

    if found then
      return v_snapshot;
    end if;

    -- Yalnız canlı ve yetkili üyelikle desteklenmeyen eski matched satırı
    -- temizlenir. Aktif eşleşme yukarıdaki üyelik snapshot'ından dönmüştür.
    delete from public.matchmaking_queue mq
    where mq.player_id = v_player_id
      and mq.room_id = v_queue_room_id
      and not exists (
        select 1
        from public.rooms live_room
        join public.room_players live_player
          on live_player.room_id = live_room.id
        where live_room.id = v_queue_room_id
          and live_player.player_id = v_player_id
          and live_player.left_at is null
          and live_room.status in ('lobby', 'active')
      );

    if not found then
      raise exception 'Matched queue membership is unavailable';
    end if;
  end if;

  -- Yalnız hâlâ bekleyen kendi satırı yenilenebilir. `room_id` dolu satır
  -- yukarıda döndürüldüğü için hiçbir retry onu silemez.
  delete from public.matchmaking_queue mq
  where mq.player_id = v_player_id
    and mq.room_id is null;

  -- 2026-08-14: '2 minutes' → '40 seconds' — bkz. dosya başı yorumu.
  -- 2026-10-15: yalnız 40 sn kuralı değil, kalp atışı da: `last_seen_at`
  -- dolu satır (touch_matchmaking çağıran istemci) 12 sn içinde görülmediyse
  -- hayalettir; NULL (eski istemci) eski 40 sn kuralıyla aynen kalır.
  delete from public.matchmaking_queue mq
  where mq.room_id is null
    and upper(mq.category_name) = upper(v_category_name)
    and not (
        (mq.last_seen_at is null
          and mq.joined_at >= now() - interval '40 seconds')
        or coalesce(mq.last_seen_at > now() - interval '12 seconds', false)
      );

  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)
    and mq.player_id <> v_player_id
    and mq.room_id is null
    and (
        (mq.last_seen_at is null
          and mq.joined_at >= now() - interval '40 seconds')
        or coalesce(mq.last_seen_at > now() - interval '12 seconds', false)
      )
    and not exists (
      select 1
      from public.blocked_users outbound_block
      where outbound_block.blocker_id = v_player_id
        and outbound_block.blocked_id = mq.player_id
    )
    and not exists (
      select 1
      from public.blocked_users inbound_block
      where inbound_block.blocker_id = mq.player_id
        and inbound_block.blocked_id = v_player_id
    )
    and not exists (
      select 1
      from public.room_players existing_player
      join public.rooms existing_room
        on existing_room.id = existing_player.room_id
      where existing_player.player_id = mq.player_id
        and existing_player.left_at is null
        and existing_room.status in ('lobby', 'active')
    )
  order by mq.joined_at asc
  limit 1
  for update skip locked;

  if v_opponent is null then
    insert into public.matchmaking_queue (
      player_id,
      category_name,
      room_id
    ) values (
      v_player_id,
      v_category_name,
      null
    );

    return json_build_object('status', 'waiting');
  end if;

  -- Sanal rastgele kuyruğu aynı rakibi bulduktan sonra tek bir gerçek ve
  -- etkin kategoriye çözülür; iki oyuncu da oda snapshot'ından aynı adı alır.
  if v_category_id is null then
    select c.id, c.name
    into v_category_id, v_category_name
    from public.categories c
    where c.is_active = true
    order by random()
    limit 1;

    if v_category_id is null then
      raise exception 'Category is not available';
    end if;
  end if;

  v_attempt := 0;
  loop
    v_attempt := v_attempt + 1;
    v_room_code := 'ZK-' || upper(
      substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
    );

    begin
      insert into public.rooms (
        code,
        host_id,
        category_id,
        question_count,
        seconds_per_question,
        status
      ) values (v_room_code, v_player_id, v_category_id, 10, 20, 'lobby')
      returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values
    (v_room_id, v_opponent, true),
    (v_room_id, v_player_id, true);

  update public.matchmaking_queue mq
  set room_id = v_room_id
  where mq.player_id = v_opponent;

  v_start := public.start_room_game(v_room_id);

  select p.display_name into v_opponent_name
  from public.profiles p
  where p.id = v_opponent;

  return json_build_object(
    'status', 'matched',
    'room_id', v_room_id,
    'code', v_room_code,
    'host_id', v_player_id,
    'category_name', v_category_name,
    'question_count', (v_start ->> 'question_count')::integer,
    'seconds_per_question', 20,
    'opponent_name', coalesce(v_opponent_name, 'Hevrik')
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.start_room_game(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_player_count integer;
  v_host_member_count integer;
  v_unready_count integer;
  v_question_count integer;
  v_server_now timestamp with time zone;
  v_crowd boolean;
  v_ready_window interval;
  v_picked uuid[];
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  if v_room.host_id is distinct from v_uid then
    raise exception 'Only the host can start this room';
  end if;

  -- Kalabalık oda = özel oda VE kapasite > 2. is_custom=false (eşleşme) ve
  -- 2 kişilik özel oda aşağıdaki eski yolu AYNEN izler.
  v_crowd := v_room.is_custom and v_room.max_players > 2;
  v_ready_window := case
    when v_crowd then interval '30 seconds'
    else interval '45 seconds'
  end;

  select
    count(*)::integer,
    count(*) filter (where rp.player_id = v_room.host_id)::integer,
    count(*) filter (where not coalesce(rp.is_ready, false))::integer
  into v_player_count, v_host_member_count, v_unready_count
  from public.room_players rp
  where rp.room_id = p_room_id
    and (not v_crowd or rp.left_at is null);

  if v_crowd then
    if v_player_count < 2 then
      raise exception 'At least two players are required';
    end if;
  elsif v_player_count <> 2 then
    raise exception 'Exactly two players are required';
  end if;

  if v_host_member_count <> 1 then
    raise exception 'Room host must be one of the two players';
  end if;

  v_server_now := clock_timestamp();

  -- Aynı host isteği ağ tekrarıyla ikinci kez gelirse aktif turu sıfırlama.
  if v_room.status = 'active' then
    update public.rooms r
    set client_ready_deadline = coalesce(
      r.client_ready_deadline,
      v_server_now + v_ready_window
    )
    where r.id = p_room_id;

    select count(*)::integer into v_question_count
    from public.room_questions rq
    where rq.room_id = p_room_id;
    return json_build_object(
      'status', 'active',
      'question_count', v_question_count
    );
  end if;

  if v_room.status <> 'lobby' then
    raise exception 'Room is not in the lobby';
  end if;

  -- Kalabalık odada "herkes hazır" şartı yoktur; host >= 2 kişiyle başlatır.
  if v_unready_count > 0 and not v_crowd then
    raise exception 'All players must be ready';
  end if;

  update public.room_players rp
  set quiz_ready_at = null
  where rp.room_id = p_room_id;

  -- Soru seçimi: önce son 14 günde odayaki oyuncuların gördüğü sorular
  -- dışlanır (son 14 günde cevaplananlar + oynanan odalarda ekrana gelenler),
  -- görülenler tükenirse eskiden görülenler rastgele sırayla tamamlar.
  -- Zorluk (2026-10-18): weighted_question_pick ~%60 kolay (1-2), ~%30 orta
  -- (3), ~%10 zor (4-5) seçer; ilk soru kolaydır; bant kısaysa başka
  -- bantlardan tamamlanır.
  if not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
  ) then
    with room_member as (
      select rp.player_id
      from public.room_players rp
      where rp.room_id = p_room_id
    ),
    recent_seen as (
      -- (1) Son 14 günde cevaplanan sorular (timeout cevapları da kayıtlı).
      select distinct pa.question_id
      from public.player_answers pa
      join room_member m on m.player_id = pa.player_id
      where pa.created_at >= v_server_now - interval '14 days'
      union
      -- (2) Son 14 günde oynanan odalarda ekrana gelen, cevaplanmamış
      --     (forfeit/yarım kalan) sorular da dahil görülen sorular.
      select distinct seen_rq.question_id
      from room_member m
      join public.room_players seen_rp
        on seen_rp.player_id = m.player_id
      join public.rooms seen_r
        on seen_r.id = seen_rp.room_id
      join public.room_questions seen_rq
        on seen_rq.room_id = seen_r.id
      where greatest(
        seen_r.created_at,
        seen_r.started_at,
        seen_r.finished_at
      ) >= v_server_now - interval '14 days'
    ),
    cand as (
      -- Kategori süzgeci: category_ids doluysa o kategorilerden; yoksa
      -- category_id doluysa o kategori; ikisi de NULL ise Karışık (hepsi).
      select q.id
      from public.questions q
      where q.is_approved = true
        and (
          case
            when v_room.category_ids is not null
              then q.category_id = any(v_room.category_ids)
            else v_room.category_id is null
              or q.category_id = v_room.category_id
          end
        )
    )
    select public.weighted_question_pick(
      (select array_agg(cand.id) from cand),
      (select coalesce(array_agg(recent_seen.question_id), '{}'::uuid[])
       from recent_seen),
      v_room.question_count
    )
    into v_picked;

    insert into public.room_questions (
      room_id,
      question_id,
      question_index,
      started_at,
      revealed_at
    )
    select
      p_room_id,
      u.qid,
      (u.ord - 1)::integer,
      null::timestamp with time zone,
      null::timestamp with time zone
    from unnest(coalesce(v_picked, '{}'::uuid[])) with ordinality as u(qid, ord);
  end if;

  select count(*)::integer into v_question_count
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_question_count <> v_room.question_count then
    raise exception
      'Not enough approved questions for this room: expected %, got %',
      v_room.question_count,
      v_question_count;
  end if;

  update public.room_questions rq
  set
    started_at = null,
    revealed_at = null
  where rq.room_id = p_room_id;

  update public.rooms
  set
    status = 'active',
    current_question_index = 0,
    started_at = v_server_now,
    finished_at = null,
    ended_reason = null,
    forfeited_by = null,
    client_ready_deadline = v_server_now + v_ready_window
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_async_duel_challenge(p_category text DEFAULT NULL::text, p_friend_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_input text;
  v_category_id uuid;
  v_open_count integer;
  v_question_ids uuid[];
  v_question_count integer;
  v_invited_name text := null;
  v_duel_id uuid;
  v_expires_at timestamptz;
  v_code text;
  v_attempt integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_category_input := nullif(btrim(coalesce(p_category, '')), '');
  if v_category_input is not null then
    select c.id into v_category_id
    from public.categories c
    where upper(c.name) = upper(v_category_input)
      and c.is_active = true
    limit 1;

    if v_category_id is null then
      raise exception 'No questions';
    end if;
  end if;

  -- Davet edilecek kişi: KABUL EDİLMİŞ arkadaş (friends tablosunda iki
  -- satır tutulur, benim satırım yeter) ve iki yönde de engelsiz. Engel,
  -- 2026-10-02_blocking_enforcement.sql ile aynı ilkeyle ifşa edilmez:
  -- engelli de arkadaş değil gibi 'Not a friend' alır.
  if p_friend_id is not null then
    if p_friend_id = v_uid
       or not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = p_friend_id
       )
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = p_friend_id)
            or (b.blocker_id = p_friend_id and b.blocked_id = v_uid)
       ) then
      raise exception 'Not a friend';
    end if;

    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = p_friend_id;
  end if;

  -- start_async_duel ile AYNI advisory kilit: ikisinin açık-düello sayımı
  -- aynı oyuncu için sıraya girer (çift dokunuş / iki RPC yarışı 5 sınırını
  -- aşamasın).
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Süresi dolmuş ama henüz süpürülmemiş düellolar sayılmaz (2026-10-15).
  select count(*) into v_open_count
  from public.async_duels
  where creator_id = v_uid
    and status = 'open'
    and expires_at > now();

  if v_open_count >= 5 then
    raise exception 'Too many open duels';
  end if;

  -- Soru seçimi start_async_duel'inkiyle BİREBİR aynı süzgeç (gerekçe orada:
  -- 2026-09-28_async_duels.sql). `rnd` bir kez hesaplanır; sıra =
  -- array_agg sırası = istemcideki index 0..6.
  select public.weighted_question_pick(
    (select array_agg(cand.id) from (
    select q.id
    from public.questions q
    join public.categories c on c.id = q.category_id
    where q.is_approved = true
      and c.is_active = true
      and (v_category_id is null or q.category_id = v_category_id)
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (
        (
          coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-')
          and q.correct_option in ('A', 'B', 'C', 'D')
        )
        or (
          q.question_type = 'true_false'
          and btrim(coalesce(q.option_c, '')) in ('', '-')
          and btrim(coalesce(q.option_d, '')) in ('', '-')
          and q.correct_option in ('A', 'B')
        )
      )
    ) cand),
    '{}'::uuid[],
    7
  ) into v_question_ids;

  v_question_count := coalesce(array_length(v_question_ids, 1), 0);
  if v_question_count < 7 then
    raise exception 'No questions';
  end if;

  -- Kod çakışması (UNIQUE) 31^8'de pratikte yok; yine de birkaç kez dener.
  loop
    v_attempt := v_attempt + 1;
    v_code := public.generate_async_duel_challenge_code();
    begin
      insert into public.async_duels (
        category_id, question_ids, creator_id, invited_id, challenge_code, status
      ) values (
        v_category_id, v_question_ids, v_uid, p_friend_id, v_code, 'open'
      )
      returning id, expires_at into v_duel_id, v_expires_at;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 8 then
          raise;
        end if;
    end;
  end loop;

  return jsonb_build_object(
    'duel_id', v_duel_id,
    'role', 'creator',
    'opponent_name', null,
    'expires_at', v_expires_at,
    'questions', public.async_duel_questions_payload(v_question_ids),
    'challenge_code', v_code,
    'invited_name', v_invited_name
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.start_async_duel(p_category text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_input text;
  v_category_id uuid;
  v_duel public.async_duels%rowtype;
  v_open_count integer;
  v_question_ids uuid[];
  v_question_count integer;
  v_role text;
  v_opponent_name text;
  v_questions jsonb;
  v_duel_id uuid;
  v_expires_at timestamptz;
  v_answered integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_category_input := nullif(btrim(coalesce(p_category, '')), '');
  if v_category_input is not null then
    select c.id into v_category_id
    from public.categories c
    where upper(c.name) = upper(v_category_input)
      and c.is_active = true
    limit 1;

    if v_category_id is null then
      raise exception 'No questions';
    end if;
  end if;

  -- Aynı oyuncunun ağ tekrarı/çift dokunuşunu sıraya koyar; iki farklı
  -- oyuncu arasındaki eşleşme satır kilidiyle (aşağıda FOR UPDATE SKIP
  -- LOCKED) zaten güvenli.
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Yarım kalmış rastgele düello (2026-10-16): rakip olarak eşleşip henüz
  -- bitirmediğim bir düello varsa YENİSİ açılmaz/eşleşilmez, aynı düello
  -- kaldığı sorudan döner. Aksi hâlde ağ tekrarı ya da uygulamayı yeniden
  -- açma, ilk düelloyu sahipsiz bırakıp ikincisine eşleştirirdi. Yanıt
  -- bu fonksiyonun kendi şeklidir (+ answered/finished: istemci
  -- AsyncDuelStart bu alanları zaten okur). Arkadaş/bağlantı meydan okumaları
  -- (invited_id/challenge_code dolu) kendi giriş yolundan sürer.
  select d.* into v_duel
  from public.async_duels d
  where d.status = 'matched'
    and d.opponent_id = v_uid
    and d.invited_id is null
    and d.challenge_code is null
    and d.expires_at > now()
    and not exists (
      select 1
      from public.async_duel_results r
      where r.duel_id = d.id
        and r.player_id = v_uid
    )
  order by d.matched_at desc nulls last, d.created_at desc
  limit 1;

  if found then
    select p.display_name into v_opponent_name
    from public.profiles p
    where p.id = v_duel.creator_id;

    select count(*)::integer into v_answered
    from public.async_duel_answers a
    where a.duel_id = v_duel.id
      and a.player_id = v_uid;

    return jsonb_build_object(
      'duel_id', v_duel.id,
      'role', 'opponent',
      'opponent_name', v_opponent_name,
      'expires_at', v_duel.expires_at,
      'questions', public.async_duel_questions_payload(v_duel.question_ids),
      'answered', v_answered,
      'finished', false
    );
  end if;

  select d.* into v_duel
  from public.async_duels d
  where d.status = 'open'
    and d.creator_id <> v_uid
    and d.invited_id is null
    -- Bağlantı/arkadaş meydan okumaları (2026-10-13_friend_challenge.sql)
    -- rastgele eşleşmeye ASLA girmez.
    and d.challenge_code is null
    and d.expires_at > now()
    -- Engelleme (2026-10-02 M5): aramızda iki yönden biri engelliyse bu
    -- düelloya eşleşmem (hata yok, sıradaki uygun düelloya bakılır;
    -- join_matchmaking ile aynı davranış).
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_uid and b.blocked_id = d.creator_id)
         or (b.blocker_id = d.creator_id and b.blocked_id = v_uid)
    )
    and (v_category_id is null or d.category_id = v_category_id)
    -- Yalnız açanın kendi turunu BİTİRDİĞİ düellolar eşleşir. Aksi hâlde
    -- ikinci oyuncu 7 soruyu oynar ama sonuç yerine "bekleniyor" görürdü;
    -- tasarımın vaadi, ikinci oyuncunun sonucu hemen görmesidir. Turunu
    -- yarıda bırakan açanın düellosu eşleşmez, 48 saatte süresi dolar.
    and exists (
      select 1
      from public.async_duel_results r
      where r.duel_id = d.id
        and r.player_id = d.creator_id
    )
  order by d.created_at asc
  limit 1
  for update skip locked;

  if found then
    -- Rakibe kendi 48 saati verilir: açık düellonun süresi açanın
    -- penceresiydi; 47. saatte eşleşen biri oynarken "Duel expired"
    -- alırdı.
    update public.async_duels
    set opponent_id = v_uid,
        status = 'matched',
        matched_at = now(),
        expires_at = greatest(expires_at, now() + interval '48 hours')
    where id = v_duel.id
    returning expires_at into v_expires_at;

    v_duel_id := v_duel.id;
    v_question_ids := v_duel.question_ids;
    v_role := 'opponent';

    select p.display_name into v_opponent_name
    from public.profiles p
    where p.id = v_duel.creator_id;
  else
    -- Süresi dolmuş ama henüz süpürülmemiş düellolar sayılmaz (2026-10-15).
    select count(*) into v_open_count
    from public.async_duels
    where creator_id = v_uid
      and status = 'open'
      and expires_at > now();

    if v_open_count >= 5 then
      raise exception 'Too many open duels';
    end if;

    -- `rnd` bir kez hesaplanır (SELECT listesinde); ORDER BY onu yeniden
    -- ÇAĞIRMAZ, aynı değeri kullanır — seçilen 7 soru ile array_agg'in
    -- verdiği sıra böylece birebir aynı kalır (index 0..6 bu sırayla).
    --
    -- Düello sorusu istemcide ATLANAMAZ: 7 soru iki oyuncuya aynı sırayla
    -- gider, cevaplar index'le eşleşir. Oda akışında istemci oynanamaz bir
    -- soruyu listeden düşürebiliyor (QuestionContentPolicy
    -- .isPlayableWithHiddenAnswer); düelloda düşürse index kayardı. Aynı
    -- süzgeç bu yüzden burada, seçimden ÖNCE uygulanır:
    --   * gizli kategoriler: lib/src/config/category_visibility.dart
    --     `hiddenCategoryIds` ile birebir aynı liste (bekçi:
    --     test/async_duel_sql_contract_test.dart);
    --   * yalnız metin soruları: görsel soruda 20 saniyelik sayaç görsel
    --     yüklenirken işler, yavaş bağlantıdaki oyuncu haksız yere kaybeder;
    --   * şıkları eksiksiz sorular: istemci boş şıkkı listeden çıkarır,
    --     aradaki bir boşluk A-D harf eşlemesini kaydırırdı;
    --   * doğru şıkkı geçerli sorular: answer_async_duel correct_option'ı
    --     cevapla ham karşılaştırır; 'a' ya da NULL taşıyan soru kimseye
    --     doğru yazdırmazdı.
    select public.weighted_question_pick(
      (select array_agg(cand.id) from (
      select q.id
      from public.questions q
      join public.categories c on c.id = q.category_id
      where q.is_approved = true
        and c.is_active = true
        and (v_category_id is null or q.category_id = v_category_id)
        and btrim(coalesce(q.prompt, '')) <> ''
        and btrim(coalesce(q.option_a, '')) not in ('', '-')
        and btrim(coalesce(q.option_b, '')) not in ('', '-')
        and (
          (
            coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
            and btrim(coalesce(q.option_c, '')) not in ('', '-')
            and btrim(coalesce(q.option_d, '')) not in ('', '-')
            and q.correct_option in ('A', 'B', 'C', 'D')
          )
          or (
            q.question_type = 'true_false'
            and btrim(coalesce(q.option_c, '')) in ('', '-')
            and btrim(coalesce(q.option_d, '')) in ('', '-')
            and q.correct_option in ('A', 'B')
          )
        )
      ) cand),
      '{}'::uuid[],
      7
    ) into v_question_ids;

    v_question_count := coalesce(array_length(v_question_ids, 1), 0);
    if v_question_count < 7 then
      raise exception 'No questions';
    end if;

    insert into public.async_duels (
      category_id, question_ids, creator_id, status
    ) values (
      v_category_id, v_question_ids, v_uid, 'open'
    )
    returning id, expires_at into v_duel_id, v_expires_at;

    v_role := 'creator';
    v_opponent_name := null;
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'index', ord.idx - 1,
      'id', q.id,
      'category_name', coalesce(c.name, 'Ziman'),
      'prompt', q.prompt,
      'option_a', q.option_a,
      'option_b', q.option_b,
      'option_c', q.option_c,
      'option_d', q.option_d,
      'question_type', q.question_type,
      'image_url', q.image_url,
      'difficulty', q.difficulty
    ) order by ord.idx
  )
  into v_questions
  from unnest(v_question_ids) with ordinality as ord(question_id, idx)
  join public.questions q on q.id = ord.question_id
  left join public.categories c on c.id = q.category_id;

  return jsonb_build_object(
    'duel_id', v_duel_id,
    'role', v_role,
    'opponent_name', v_opponent_name,
    'expires_at', v_expires_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$function$;

revoke all on function public.create_online_room_impl(text[], integer, integer, integer, integer, boolean) from public, anon, authenticated;
grant execute on function public.create_online_room_impl(text[], integer, integer, integer, integer, boolean) to service_role;
revoke all on function public.create_online_room_v2(text[], integer, integer, integer, integer) from public, anon;
grant execute on function public.create_online_room_v2(text[], integer, integer, integer, integer) to authenticated, service_role;

commit;
