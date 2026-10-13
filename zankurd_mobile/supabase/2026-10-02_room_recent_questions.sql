-- 2026-10-02: start_room_game — son 14 günde görülen soruları seçimden çıkar.
--
-- NİÇİN: `start_room_game` soruları kategoriden TAMAMEN rastgele seçiyordu.
--   Küçük onaylı kategorilerde (Sînema 127, Siyaset ~140) iki oyuncunun art
--   arda oynadığı iki 10'luk maçta ortak soru çıkma olasılığı %50'nin üstüne
--   çıkıyordu; oyuncu aynı soruları tekrar görünce maç ezber oluyor.
--
-- NE DEĞİŞTİ: yalnız `start_room_game` içindeki seç-insert bloğu. Artık:
--   1) Odayaki oyuncuların `player_answers` üzerinden son 14 GÜNDE cevapladığı
--      sorular, ve
--   2) aynı oyuncuların son 14 günde katıldığı odalarda `room_questions` ile
--      ekrana gelen (cevaplanmasa da görülen) sorular
--   önce dışlanır; aday havuzu yetersiz kalırsa (küçük kategori / çok oynanmış
--   oyuncu) eskiden görülenler rastgele sırayla tamamlar. Seçilen soru sayısı
--   her zaman `question_count` (10) olur; kategorinin toplam onaylı sorusu
--   10'dan azsa eski davranış aynıdır ve aynı hata yükselir.
--   İmza `(uuid) -> json`, LANGUAGE plpgsql, SECURITY DEFINER, search_path,
--   hata metinleri ve dönen JSON anahtarları (`status`, `question_count`)
--   AYNEN korunur; yalnız seçim mantığı değişti.
--   `join_matchmaking` ve `get_room_questions` dosyaları değişmedi;
--   `join_matchmaking` eşleşince bu fonksiyonu çağırdığı için aynı iyileşmeden
--   yararlanır.
--   Performans: `player_answers (player_id, created_at)` indeksi eklenir
--   (`room_players_player_room_idx` zaten mevcut).
--
-- GERİ ALMA: eski gövde `canli_fonksiyonlar.sql` (satır 333-484) ve
--   `zankurd_mobile/supabase/2026-08-02_multiplayer_session_hardening.sql`
--   içindeki `create or replace function public.start_room_game(...)` ile
--   yeniden kurulur; indeks `drop index if exists
--   player_answers_player_created_at_idx;` ile silinir.
--
-- UYGULAMA: Supabase SQL Editor'de tek seferde çalıştır. (Bu dosya yazılmıştır;
--   veritabanına bağlanılmamış, supabase komutu çalıştırılmamıştır.)

begin;

create index if not exists player_answers_player_created_at_idx
  on public.player_answers (player_id, created_at);

create or replace function public.start_room_game(p_room_id uuid)
 returns json
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_player_count integer;
  v_host_member_count integer;
  v_unready_count integer;
  v_question_count integer;
  v_server_now timestamp with time zone;
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

  select
    count(*)::integer,
    count(*) filter (where rp.player_id = v_room.host_id)::integer,
    count(*) filter (where not coalesce(rp.is_ready, false))::integer
  into v_player_count, v_host_member_count, v_unready_count
  from public.room_players rp
  where rp.room_id = p_room_id;

  if v_player_count <> 2 then
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
      v_server_now + interval '2 minutes'
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

  if v_unready_count > 0 then
    raise exception 'All players must be ready';
  end if;

  update public.room_players rp
  set quiz_ready_at = null
  where rp.room_id = p_room_id;

  -- Soru seçimi: önce son 14 günde odayaki oyuncuların gördüğü sorular
  -- dışlanır (son 14 günde cevaplananlar + oynanan odalarda ekrana gelenler),
  -- görülenler tükenirse eskiden görülenler rastgele sırayla tamamlar.
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
    candidates as (
      -- Görülmemişler (false < true) önce; her grupta rastgele sıra.
      select
        q.id,
        (s.question_id is not null) as already_seen,
        random() as random_order
      from public.questions q
      left join recent_seen s on s.question_id = q.id
      where q.is_approved = true
        and (
          v_room.category_id is null
          or q.category_id = v_room.category_id
        )
    ),
    ranked as (
      select
        c.id,
        c.random_order,
        row_number() over (
          order by c.already_seen asc, c.random_order
        ) as pick_rank
      from candidates c
    )
    insert into public.room_questions (
      room_id,
      question_id,
      question_index,
      started_at,
      revealed_at
    )
    select
      p_room_id,
      picked.id,
      (
        row_number() over (order by picked.random_order)
      )::integer - 1 as question_index,
      null::timestamp with time zone as started_at,
      null::timestamp with time zone as revealed_at
    from ranked picked
    where picked.pick_rank <= v_room.question_count;
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
    client_ready_deadline = v_server_now + interval '2 minutes'
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$function$;

-- DOĞRULAMA: fonksiyon var, imza/dönüş tipi/SECURITY DEFINER/search_path ve
-- JSON anahtarları değişmemiş olmalı. İmza bozuksa transaction başarısız olur.
do $verify$
declare
  v_def text;
  v_config text[];
begin
  if to_regprocedure('public.start_room_game(uuid)') is null then
    raise exception 'Dogrulama hatasi: public.start_room_game(uuid) bulunamadi';
  end if;

  select coalesce(p.proconfig, array[]::text[])
  into v_config
  from pg_proc p
  where p.oid = to_regprocedure('public.start_room_game(uuid)');

  if not exists (
    select 1
    from unnest(v_config) cfg
    where split_part(cfg, '=', 1) = 'search_path'
      and split_part(cfg, '=', 2) in ('public', '"public"', '''public''')
  ) then
    raise exception 'Dogrulama hatasi: search_path = public korunmadi (proconfig: %)', v_config;
  end if;

  v_def := pg_get_functiondef('public.start_room_game(uuid)'::regprocedure);

  if v_def not like '%RETURNS json%' then
    raise exception 'Dogrulama hatasi: donus tipi json degil';
  end if;
  if v_def not like '%LANGUAGE plpgsql%' then
    raise exception 'Dogrulama hatasi: dil plpgsql degil';
  end if;
  if v_def not like '%SECURITY DEFINER%' then
    raise exception 'Dogrulama hatasi: SECURITY DEFINER kayip';
  end if;
  if v_def not like '%''status'', ''active''%' then
    raise exception 'Dogrulama hatasi: ''status'' JSON anahtari kayip';
  end if;
  if v_def not like '%''question_count''%' then
    raise exception 'Dogrulama hatasi: ''question_count'' JSON anahtari kayip';
  end if;
  if v_def not like '%''Not enough approved questions for this room%' then
    raise exception 'Dogrulama hatasi: yetersiz soru hata metni kayip';
  end if;
  if v_def not like '%recent_seen%' then
    raise exception 'Dogrulama hatasi: son-14-gun dislama mantigi govdeye yazilmamis';
  end if;

  raise notice 'OK: public.start_room_game(uuid) -> json, SECURITY DEFINER, search_path=public, yeni secim govdesi yerinde';
end;
$verify$;

commit;
