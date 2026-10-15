-- 2026-10-15: 1v1 CANLILIK — hayalet bekleyen, öğretici kilidi, sessiz tek yol.
--
-- NİÇİN (canlı veri, 2026-10-15): Bir oyuncu rakibi görüp öteki görmüyor,
-- maçlar ilk saniyelerde ölüyordu. Terk edilen (forfeit) 6 1v1 odasının 6'sında
-- bir oyuncu `room_players.quiz_ready_at`ı HİÇ yazmamıştı, öteki başlangıçtan
-- 3 sn sonra hazırdı; çoğu ilk kez online oynayan kişiydi. İstemci hazır
-- sinyalini ilk-çalıştırma öğreticisi kapanana kadar tutuyordu (bu değişiklik
-- istemci tarafında kaldırıldı). Bekleyen taraf ise 2 dakika boyunca bir
-- hayaletle eşleştiği için boş ekrana bakıp çıkıyordu:
--   - `matchmaking_queue` bekleyen satırının canlılık sinyali yoktu; yalnız
--     40 sn'den eski satır siliniyordu. Uygulamayı kapatan/arka plana atan ya da
--     iptali başarısız olan oyuncu 40 sn boyunca "eşleştirilebilir" kalıyordu.
--   - Bekleyen, eşleştiğini yalnız realtime akışından öğreniyordu; akış
--     sessizce koparsa ~20 sn sonraki zaman aşımına kadar haber yoktu.
--
-- NE YAPAR:
--   1. `matchmaking_queue.last_seen_at` (NULL = kalp atışı atmayan eski istemci).
--   2. `touch_matchmaking()`: bekleyen istemci 3 sn'de bir çağırır. Canlı oda
--      üyeliği varsa join_matchmaking'in 'matched' özetinin AYNISINI döndürür
--      (realtime kaçsa bile eşleşmeyi bulur); yoksa ve bekleyen satırı varsa
--      `last_seen_at = now()` yazar ve {"status":"waiting"}; yoksa "none".
--   3. `join_matchmaking`: bekleyen rakip yalnız (last_seen_at NULL ve 40 sn
--      kuralı) YA DA (last_seen_at son 12 sn içinde) ise eşleştirilebilir;
--      eşleştirilemeyen bekleyen satırlar eşleştirmeden önce silinir. Eski
--      istemci (NULL) bugünkü gibi eşleşir. Kendi satırı `last_seen_at` NULL
--      girer: eski istemci kalp atışı atmadığından now() yazmak onu 12. sn'de
--      hayalet sayardı; yeni istemci ilk `touch_matchmaking`de işaretlenir.
--   4. Maç öncesi istemci-hazır süresi 2 dk -> 45 sn: `start_room_game` (iki
--      yerde) ve `mark_room_client_ready` (yalnız aralık değişti).
-- Gövdeler CANLI tanımların kopyasıdır; yalnız yukarıdakiler değişti.
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-10-15_matchmaking_canlilik.sql`
-- Geri alma: eski gövdeler 2026-08-14_matchmaking_queue_ttl_alignment.sql,
-- 2026-10-02_room_recent_questions.sql ve 2026-08-02_multiplayer_session_hardening.sql
-- içindedir; kolon zararsız kalabilir.

begin;

alter table public.matchmaking_queue
  add column if not exists last_seen_at timestamptz;

create or replace function public.touch_matchmaking()
returns json
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_player_id uuid := auth.uid();
  v_category text;
  v_snapshot json;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select mq.category_name into v_category
  from public.matchmaking_queue mq
  where mq.player_id = v_player_id
    and mq.room_id is null;

  -- join_matchmaking eşleşmede bekleyen satırı `for update skip locked` ile
  -- seçer; kalp atışı satırı tam o anda kilitlerse çift birbirini kaçırırdı.
  -- Aynı kategori kilidi ikisini sıralar (join de satırdan ÖNCE alır).
  if v_category is not null then
    perform pg_advisory_xact_lock(
      hashtextextended('matchmaking:' || lower(v_category), 0)
    );
  end if;

  select json_build_object(
    'status', 'matched',
    'room_id', r.id,
    'code', r.code,
    'host_id', r.host_id,
    'category_name', coalesce(c.name, 'Ziman'),
    'question_count', r.question_count,
    'seconds_per_question', coalesce(r.seconds_per_question, 20),
    'opponent_name', coalesce(opponent.display_name, 'Hevrik')
  )
  into v_snapshot
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_player_id
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
  limit 1;

  if found then
    return v_snapshot;
  end if;

  if v_category is not null then
    update public.matchmaking_queue mq
    set last_seen_at = now()
    where mq.player_id = v_player_id
      and mq.room_id is null;

    if found then
      return json_build_object('status', 'waiting');
    end if;
  end if;

  return json_build_object('status', 'none');
end;
$function$;

revoke all on function public.touch_matchmaking() from public, anon;
grant execute on function public.touch_matchmaking() to authenticated;

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
    'category_name', coalesce(c.name, 'Ziman'),
    'question_count', r.question_count,
    'seconds_per_question', coalesce(r.seconds_per_question, 20),
    'opponent_name', coalesce(opponent.display_name, 'Hevrik')
  )
  into v_snapshot
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_player_id
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
      'category_name', coalesce(c.name, 'Ziman'),
      'question_count', r.question_count,
      'seconds_per_question', coalesce(r.seconds_per_question, 20),
      'opponent_name', coalesce(opponent.display_name, 'Hevrik')
    )
    into v_snapshot
    from public.rooms r
    join public.room_players mine
      on mine.room_id = r.id and mine.player_id = v_player_id
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
      v_server_now + interval '45 seconds'
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
    client_ready_deadline = v_server_now + interval '45 seconds'
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_room_client_ready(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_player_count integer;
  v_on_time_ready_count integer;
  v_not_ready_player_id uuid;
  v_server_now timestamp with time zone;
  v_current_started_at timestamp with time zone;
  v_current_deadline timestamp with time zone;
  v_remaining_ms integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found or v_room.status <> 'active' then
    raise exception 'Room is not active';
  end if;

  v_server_now := clock_timestamp();

  -- Eski bir aktif oda bu sütun eklenmeden önce açılmışsa ilk çağrı mutlak
  -- bariyeri yalnız bir kez kurar; sonraki retry'lar süreyi uzatamaz.
  if v_room.client_ready_deadline is null then
    v_room.client_ready_deadline := v_server_now + interval '45 seconds';
    update public.rooms r
    set client_ready_deadline = v_room.client_ready_deadline
    where r.id = p_room_id;
  end if;

  update public.room_players rp
  set quiz_ready_at = coalesce(rp.quiz_ready_at, v_server_now)
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where rp.quiz_ready_at is not null
        and rp.quiz_ready_at <= v_room.client_ready_deadline
    )::integer
  into v_player_count, v_on_time_ready_count
  from public.room_players rp
  where rp.room_id = p_room_id;

  if v_player_count <> 2 then
    raise exception 'Exactly two players are required';
  end if;

  select rq.started_at into v_current_started_at
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_index = coalesce(v_room.current_question_index, 0);

  if not found then
    raise exception 'Current room question is missing';
  end if;

  if v_current_started_at is null
     and v_player_count = 2
     and v_on_time_ready_count = 2 then
    update public.room_questions rq
    set started_at = coalesce(rq.started_at, v_server_now)
    where rq.room_id = p_room_id
      and rq.question_index = coalesce(v_room.current_question_index, 0)
    returning rq.started_at into v_current_started_at;
  end if;

  if v_current_started_at is null
     and v_server_now >= v_room.client_ready_deadline
     and v_on_time_ready_count < 2 then
    -- Tek zamanında hazır oyuncu varsa rakip forfeit olur. İki taraf da
    -- gelmediyse rastgele bir kullanıcıyı suçlamamak için alan null kalır.
    if v_on_time_ready_count = 1 then
      select rp.player_id into v_not_ready_player_id
      from public.room_players rp
      where rp.room_id = p_room_id
        and (
          rp.quiz_ready_at is null
          or rp.quiz_ready_at > v_room.client_ready_deadline
        )
      order by rp.player_id
      limit 1;
    end if;

    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, v_server_now),
      ended_reason = 'opponent_not_ready',
      forfeited_by = v_not_ready_player_id
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    return json_build_object(
      'status', 'finished',
      'reason', 'opponent_not_ready',
      'forfeited_by', v_not_ready_player_id,
      'server_now', v_server_now,
      'current_question_index', coalesce(v_room.current_question_index, 0),
      'current_question_started_at', null,
      'current_question_deadline', null,
      'current_question_remaining_ms', 0
    );
  end if;

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
    'status', case
      when v_current_started_at is null then 'waiting'
      else 'ready'
    end,
    'server_now', v_server_now,
    'current_question_index', coalesce(v_room.current_question_index, 0),
    'current_question_started_at', v_current_started_at,
    'current_question_deadline', v_current_deadline,
    'current_question_remaining_ms', v_remaining_ms
  );
end;
$function$;

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'matchmaking_queue'
      and column_name = 'last_seen_at'
  ) then
    raise exception 'last_seen_at kolonu eklenemedi';
  end if;
  if pg_get_functiondef('public.join_matchmaking(text)'::regprocedure)
       not like '%interval ''12 seconds''%' then
    raise exception 'join_matchmaking 12 sn kuralını içermiyor';
  end if;
  if pg_get_functiondef('public.start_room_game(uuid)'::regprocedure) like '%2 minutes%'
     or pg_get_functiondef('public.mark_room_client_ready(uuid)'::regprocedure) like '%2 minutes%' then
    raise exception 'maç öncesi hazır süresi hâlâ 2 dakika';
  end if;
  if has_function_privilege('anon', 'public.touch_matchmaking()', 'execute') then
    raise exception 'touch_matchmaking anon için açık';
  end if;
end;
$$;

commit;
