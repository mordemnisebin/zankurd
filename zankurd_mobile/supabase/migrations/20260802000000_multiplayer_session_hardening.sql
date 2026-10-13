-- ZanKurd 1v1 oturum bütünlüğü.
--
-- Bu ileri göç eski uygulanmış dosyaları yeniden çalıştırmaz. Oda oluşturma,
-- tam iki üyelik, iki istemcili başlangıç bariyeri, sunucu deadline'ı,
-- CAS ilerletme/bitiş, eşleştirme kilit sırası ve güvenli resume snapshot'ını
-- tek sunucu sözleşmesinde birleştirir.
--
-- Üretime otomatik uygulanmamalıdır; önce staging/preview veritabanında
-- sözleşme ve iki istemcili senaryo doğrulanmalıdır.

begin;

alter table public.rooms
  add column if not exists ended_reason text;

alter table public.rooms
  add column if not exists forfeited_by uuid
    references public.profiles(id) on delete set null;

alter table public.rooms
  add column if not exists client_ready_deadline timestamp with time zone;

-- Tamamlanmış oda geçmişi hesap silinince korunur. Canlı odalarda ise host
-- olmadan devam edilemeyeceği için uygulama-katmanı invariant'ı CHECK ile de
-- güvenceye alınır.
alter table public.rooms
  alter column host_id drop not null;
alter table public.rooms
  drop constraint if exists rooms_host_id_fkey;
alter table public.rooms
  add constraint rooms_host_id_fkey
  foreign key (host_id) references public.profiles(id) on delete set null;
alter table public.rooms
  drop constraint if exists rooms_live_host_required;
alter table public.rooms
  add constraint rooms_live_host_required
  check (status not in ('lobby', 'active') or host_id is not null);

alter table public.room_players
  add column if not exists quiz_ready_at timestamp with time zone;

alter table public.room_questions
  add column if not exists revealed_at timestamp with time zone;

-- Sonuç ekranı gösterildikten sonra oyuncu başına kalıcı, idempotent makbuz.
-- Tablo istemciye kapalıdır; hem okuma hem yazma yalnız aşağıdaki yetkili
-- RPC'lerden geçer.
create table if not exists public.room_result_receipts (
  room_id uuid not null
    references public.rooms(id) on delete cascade,
  player_id uuid not null
    references public.profiles(id) on delete cascade,
  acknowledged_at timestamp with time zone not null
    default clock_timestamp(),
  primary key (room_id, player_id)
);

alter table public.room_result_receipts enable row level security;
alter table public.room_result_receipts force row level security;
revoke all on table public.room_result_receipts
  from public, anon, authenticated;

-- Hesap silme, kalan oyuncunun henüz görmediği sonucu bozmadan kişisel
-- satırları kaldırabilsin. Payload yalnız sonuç sahibinin kendi cevaplarını
-- taşır; silinen rakibin kimliği sabit, kişisel olmayan UUID/ad ile değiştirilir.
create table if not exists public.room_result_snapshots (
  room_id uuid not null
    references public.rooms(id) on delete cascade,
  player_id uuid not null
    references public.profiles(id) on delete cascade,
  payload jsonb not null,
  finished_at timestamp with time zone not null,
  room_created_at timestamp with time zone not null,
  created_at timestamp with time zone not null default clock_timestamp(),
  primary key (room_id, player_id)
);

alter table public.room_result_snapshots enable row level security;
alter table public.room_result_snapshots force row level security;
revoke all on table public.room_result_snapshots
  from public, anon, authenticated;

create index if not exists room_players_player_room_idx
  on public.room_players (player_id, room_id);
create unique index if not exists rooms_lobby_upper_code_uidx
  on public.rooms (upper(code)) where status = 'lobby';

-- Oda ve üyelik kurulumu artık yalnız transaction içindeki yetkili RPC'lerden
-- geçer. RLS politikası kalsa bile tablo yetkisi olmadan istemci INSERT
-- yapamaz; eski oda-üyelik politikası da açıkça kaldırılır.
drop policy if exists "Players can join as themselves"
  on public.room_players;
drop policy if exists "Players update their own room membership"
  on public.room_players;
drop policy if exists "Hosts can update their own rooms"
  on public.rooms;
revoke insert on public.rooms from public, anon, authenticated;
revoke insert on public.room_players from public, anon, authenticated;
revoke update, delete on public.rooms from public, anon, authenticated;
revoke update, delete on public.room_players
  from public, anon, authenticated;
revoke insert, update, delete on public.room_questions
  from public, anon, authenticated;

-- Cevap satırındaki doğruluk/puan alanları yalnız güvenli RPC snapshot'ından
-- ve explicit reveal sonrasında okunabilir. RLS politikası bulunsa bile tablo
-- yetkisi olmadan REST üzerinden ilk cevap sonucu sorgulanamaz.
revoke select on public.player_answers from public, anon, authenticated;

-- Kuyruk yazımları yalnız aşağıdaki kilitli RPC'lerden geçer.
drop policy if exists "Allow insert own matchmaking queue entry"
  on public.matchmaking_queue;
drop policy if exists "Allow delete own matchmaking queue entry"
  on public.matchmaking_queue;
revoke insert, delete on public.matchmaking_queue
  from public, anon, authenticated;

-- Deadline CAS'i, eksik rakip cevabını sunucu TIMEOUT'u olarak tamamlar.
-- Mevcut tetikleyici normalde başka player_id'yi reddeder; istisna yalnız
-- aktif/current soru, dolmuş sunucu deadline'ı ve değiştirilemez sıfır-puan
-- TIMEOUT alanlarının tümü doğrulandığında açılır.
create or replace function public.enforce_current_room_question()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_server_timeout_allowed boolean := false;
begin
  if v_uid is not null and new.player_id is distinct from v_uid then
    select exists (
      select 1
      from public.rooms r
      join public.room_questions rq on rq.room_id = r.id
      join public.room_players caller
        on caller.room_id = r.id and caller.player_id = v_uid
      join public.room_players target
        on target.room_id = r.id and target.player_id = new.player_id
      where r.id = new.room_id
        and r.status = 'active'
        and rq.question_id = new.question_id
        and rq.question_index = r.current_question_index
        and rq.started_at is not null
        and clock_timestamp() >= rq.started_at + make_interval(
          secs => greatest(1, coalesce(r.seconds_per_question, 20))
        )
        and new.selected_option = 'TIMEOUT'
        and new.is_correct is false
        and new.response_ms = greatest(
          1,
          coalesce(r.seconds_per_question, 20)
        ) * 1000
        and new.points_awarded = 0
        and (
          select count(*)
          from public.room_players exact_players
          where exact_players.room_id = r.id
        ) = 2
    ) into v_server_timeout_allowed;

    if not v_server_timeout_allowed then
      raise exception 'Answer player does not match authenticated user';
    end if;
  end if;

  if not exists (
    select 1
    from public.room_questions rq
    join public.rooms r on r.id = rq.room_id
    where rq.room_id = new.room_id
      and rq.question_id = new.question_id
      and rq.question_index = r.current_question_index
      and r.status = 'active'
  ) then
    raise exception 'Question is not the current active room question';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_current_room_question()
  from public, anon, authenticated;

-- Tetikleyicinin KENDİSİ bu dosyada kurulmuyordu; yalnız gövdesi
-- değiştiriliyordu. Tetikleyici `2026-07-29_release_readiness_hardening.sql`
-- içinde yaratılmıştı — o göç uygulanmamış ya da tetikleyici sonradan
-- düşürülmüşse bu dosya bekçi fonksiyonunu kurar ve onu hiçbir şey çağırmaz:
-- koruma sessizce yok olur. Göç kendi kendine yeterli olmalı.
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'player_answers_current_question_trg'
      and tgrelid = 'public.player_answers'::regclass
      and not tgisinternal
  ) then
    create trigger player_answers_current_question_trg
      before insert or update on public.player_answers
      for each row execute function public.enforce_current_room_question();
  end if;
end $$;

-- `create or replace` bir fonksiyonun dönüş tipini ya da parametre ADINI
-- değiştiremez; denerse `42P13` ile bütün transaction geri alınır. Aşağıdaki
-- üç fonksiyonun izlenen bir önceki tanımı repoda YOK (canlıya repo dışından
-- gelmişler) — yani imzalarının bu dosyadakiyle aynı olduğu doğrulanamıyor.
-- `advance_room_question` için zaten uygulanan çözüm burada da uygulanır:
-- önce düşür, sonra kur. Yetkiler her birinin ardından yeniden veriliyor.
drop function if exists public.create_online_room(text, integer);
drop function if exists public.cancel_matchmaking();
drop function if exists public.leave_room(uuid);

create or replace function public.create_online_room(
  p_category_name text,
  p_seconds_per_question integer
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_category_id uuid;
  v_category_name text;
  v_existing record;
  v_room_id uuid;
  v_room_code text;
  v_attempt integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_seconds_per_question is null
     or p_seconds_per_question not in (20, 30, 45, 60) then
    raise exception 'Unsupported seconds per question';
  end if;

  select c.id, c.name
  into v_category_id, v_category_name
  from public.categories c
  where upper(c.name) = upper(trim(p_category_name))
    and c.is_active = true
  limit 1;

  if v_category_id is null then
    raise exception 'Category is not available';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));

  -- Manuel oda oluşturma ile hızlı eşleştirme aynı oyuncu için yarışamaz.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Ağ tekrarı ya da çift dokunuş ikinci bir canlı oda üretmez. İstemciye
  -- yeni istek yerine mevcut, yetkili sunucu snapshot'ı döner.
  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    coalesce(c.name, 'Ziman') as category_name
  into v_existing
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id and rp.player_id = v_uid
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
      'status', v_existing.status
    );
  end if;

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
      ) values (
        v_room_code,
        v_uid,
        v_category_id,
        10,
        p_seconds_per_question,
        'lobby'
      ) returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room_id, v_uid, true);

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room_id,
    'code', v_room_code,
    'host_id', v_uid,
    'category_name', v_category_name,
    'question_count', 10,
    'seconds_per_question', p_seconds_per_question,
    'status', 'lobby'
  );
end;
$$;

revoke all on function public.create_online_room(text, integer)
  from public, anon;
grant execute on function public.create_online_room(text, integer)
  to authenticated;

create or replace function public.join_room_by_code(
  p_code text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_existing_room_id uuid;
  v_player_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- create/match/join aynı oyuncu kilidini paylaşır. Mevcut canlı oda normal
  -- snapshot ile okunur; başka oda satırını kilitleyip cross-room deadlock
  -- yaratılmaz.
  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1;

  -- `start_room_game` ve `set_room_ready` de aynı satırı kilitler.
  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where upper(r.code) = upper(trim(p_code))
    and r.status = 'lobby'
  limit 1
  for update of r;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  if v_existing_room_id is not null
     and v_existing_room_id <> v_room.id then
    raise exception 'Player is already in another live room';
  end if;

  -- Ağ tekrarı mevcut üyeyi kapasite hatasına düşürmez.
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
      'category_name', v_room.category_name
    );
  end if;

  select count(*)::integer into v_player_count
  from public.room_players rp
  where rp.room_id = v_room.id;

  if v_player_count >= 2 then
    raise exception 'Room is full';
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'category_name', v_room.category_name
  );
end;
$$;

revoke all on function public.join_room_by_code(text) from public, anon;
grant execute on function public.join_room_by_code(text) to authenticated;

create or replace function public.set_room_ready(
  p_room_id uuid,
  p_is_ready boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
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

  if v_room.status <> 'lobby' then
    raise exception 'Room is not in the lobby';
  end if;

  update public.room_players rp
  set is_ready = coalesce(p_is_ready, false)
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if not found then
    raise exception 'Player is not in the room';
  end if;
end;
$$;

revoke all on function public.set_room_ready(uuid, boolean) from public, anon;
grant execute on function public.set_room_ready(uuid, boolean) to authenticated;

create or replace function public.start_room_game(
  p_room_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
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

  if not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
  ) then
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
      picked.question_index,
      null::timestamp with time zone as started_at,
      null::timestamp with time zone as revealed_at
    from (
      select
        selected.id,
        row_number() over (
          order by selected.random_order
        )::integer - 1 as question_index
      from (
        select q.id, random() as random_order
        from public.questions q
        where q.is_approved = true
          and (
            v_room.category_id is null
            or q.category_id = v_room.category_id
          )
        order by random_order
        limit v_room.question_count
      ) selected
    ) picked;
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
$$;

revoke all on function public.start_room_game(uuid) from public, anon;
grant execute on function public.start_room_game(uuid) to authenticated;

create or replace function public.mark_room_client_ready(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
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
    v_room.client_ready_deadline := v_server_now + interval '2 minutes';
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
$$;

revoke all on function public.mark_room_client_ready(uuid) from public, anon;
grant execute on function public.mark_room_client_ready(uuid) to authenticated;

create or replace function public.join_matchmaking(
  p_category_name text
) returns json
language plpgsql
security definer
set search_path = public
as $$
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

  delete from public.matchmaking_queue mq
  where mq.room_id is null
    and upper(mq.category_name) = upper(v_category_name)
    and mq.joined_at < now() - interval '2 minutes';

  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)
    and mq.player_id <> v_player_id
    and mq.room_id is null
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
$$;

revoke all on function public.join_matchmaking(text) from public, anon;
grant execute on function public.join_matchmaking(text) to authenticated;

create or replace function public.cancel_matchmaking()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room_id uuid;
  v_live_room_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Queue işaretinden önce yetkili canlı üyelik kaynak kabul edilir.
  select r.id into v_live_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    return json_build_object(
      'status', 'matched',
      'room_id', v_live_room_id
    );
  end if;

  select mq.room_id into v_room_id
  from public.matchmaking_queue mq
  where mq.player_id = v_uid
  for update;

  if found then
    if v_room_id is not null then
      -- Rakibin transaction'ı queue kilidini bıraktıktan sonra üyeliği tekrar
      -- denetle; ilk sorgu eşleşme commitinden hemen önce çalışmış olabilir.
      select r.id into v_live_room_id
      from public.rooms r
      join public.room_players rp on rp.room_id = r.id
      where r.id = v_room_id
        and rp.player_id = v_uid
        and r.status in ('lobby', 'active');

      if found then
        return json_build_object(
          'status', 'matched',
          'room_id', v_live_room_id
        );
      end if;

      delete from public.matchmaking_queue mq
      where mq.player_id = v_uid
        and mq.room_id = v_room_id;
      return json_build_object('status', 'cancelled');
    end if;

    delete from public.matchmaking_queue mq
    where mq.player_id = v_uid
      and mq.room_id is null;
    return json_build_object('status', 'cancelled');
  end if;

  return json_build_object('status', 'idle');
end;
$$;

revoke all on function public.cancel_matchmaking() from public, anon;
grant execute on function public.cancel_matchmaking() to authenticated;

create or replace function public.finish_room_game(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_question_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  if v_room.status = 'finished' then
    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;
    return json_build_object(
      'status', 'finished',
      'reason', coalesce(v_room.ended_reason, 'already_finished')
    );
  end if;

  select count(*)::integer into v_question_count
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_room.status <> 'active'
     or v_question_count < 1
     or coalesce(v_room.current_question_index, -1) < v_question_count then
    raise exception 'Room is not ready to finish';
  end if;

  update public.rooms r
  set
    status = 'finished',
    finished_at = coalesce(r.finished_at, clock_timestamp()),
    ended_reason = 'completed',
    forfeited_by = null
  where r.id = p_room_id;

  -- Waiting oyuncunun eşleşme bildirimi maç boyunca kalır; yalnız oda artık
  -- terminal olduktan sonra temizlenir.
  delete from public.matchmaking_queue mq
  where mq.room_id = p_room_id;

  return json_build_object('status', 'finished', 'reason', 'completed');
end;
$$;

revoke all on function public.finish_room_game(uuid) from public, anon;
grant execute on function public.finish_room_game(uuid) to authenticated;

create or replace function public.leave_room(
  p_room_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  -- Tekrarlanan çıkış terminal maçın tarihsel üyeliğini değiştirmez.
  if v_room.status not in ('lobby', 'active') then
    return json_build_object(
      'status', v_room.status,
      'reason', coalesce(v_room.ended_reason, 'already_finished'),
      'forfeited_by', v_room.forfeited_by
    );
  end if;

  update public.room_players rp
  set is_ready = false
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if v_room.status = 'active' then
    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'forfeit',
      forfeited_by = v_uid
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    return json_build_object(
      'status', 'finished',
      'reason', 'forfeit',
      'forfeited_by', v_uid
    );
  end if;

  if v_room.status = 'lobby' and v_room.host_id = v_uid then
    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'host_left',
      forfeited_by = null
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    return json_build_object(
      'status', 'finished',
      'reason', 'host_left',
      'forfeited_by', null
    );
  end if;

  if v_room.status = 'lobby' then
    delete from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = v_uid;
    return json_build_object(
      'status', 'left',
      'reason', 'guest_left',
      'forfeited_by', null
    );
  end if;

  return json_build_object(
    'status', v_room.status,
    'reason', coalesce(v_room.ended_reason, 'already_finished'),
    'forfeited_by', v_room.forfeited_by
  );
end;
$$;

revoke all on function public.leave_room(uuid) from public, anon;
grant execute on function public.leave_room(uuid) to authenticated;

-- Hesap silme rakibin tamamlanmış maç kanıtını ve oda geçmişini korur. Önce
-- tüm canlı oturumlar terminalize edilir; yalnız silinen kullanıcının kişisel
-- cevap/üyelik kayıtları sonrasında kaldırılır.
create or replace function public.delete_my_account()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_room record;
  v_completed_room record;
  v_remaining_player record;
  v_players jsonb;
  v_question_ids jsonb;
  v_answers jsonb;
  v_winner_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  -- Silinen oyuncunun cascade'i bitmiş maçtaki iki-skor kanıtını kaldırmadan
  -- önce, yalnız kalan ve henüz onaylamamış oyuncu için anonim snapshot yaz.
  for v_completed_room in
    select
      completed_room.id,
      completed_room.code,
      completed_room.host_id,
      completed_room.question_count,
      completed_room.seconds_per_question,
      completed_room.current_question_index,
      completed_room.ended_reason,
      completed_room.forfeited_by,
      completed_room.finished_at,
      completed_room.created_at,
      coalesce(category.name, 'Ziman') as category_name
    from public.rooms completed_room
    join public.room_players deleting_member
      on deleting_member.room_id = completed_room.id
      and deleting_member.player_id = v_user_id
    left join public.categories category
      on category.id = completed_room.category_id
    where completed_room.status = 'finished'
      and completed_room.ended_reason = 'completed'
      and completed_room.forfeited_by is null
      and completed_room.finished_at is not null
      and completed_room.question_count > 0
      and coalesce(completed_room.current_question_index, -1)
        = completed_room.question_count
      and exists (
        select 1
        from public.room_players exact_players
        where exact_players.room_id = completed_room.id
        having count(*) = 2
      )
      and exists (
        select 1
        from public.room_questions revealed_question
        where revealed_question.room_id = completed_room.id
        having count(*) = completed_room.question_count
          and count(distinct revealed_question.question_index)
            = completed_room.question_count
          and min(revealed_question.question_index) = 0
          and max(revealed_question.question_index)
            = completed_room.question_count - 1
          and bool_and(revealed_question.revealed_at is not null)
      )
      and exists (
        select 1
        from public.player_answers exact_answer
        join public.room_questions answered_question
          on answered_question.room_id = exact_answer.room_id
          and answered_question.question_id = exact_answer.question_id
        join public.room_players answering_player
          on answering_player.room_id = exact_answer.room_id
          and answering_player.player_id = exact_answer.player_id
        where exact_answer.room_id = completed_room.id
        having count(*) = completed_room.question_count * 2
      )
      and not exists (
        select 1
        from public.room_players member
        where member.room_id = completed_room.id
          and (
            select count(*)
            from public.player_answers own_answer
            join public.room_questions own_question
              on own_question.room_id = own_answer.room_id
              and own_question.question_id = own_answer.question_id
            where own_answer.room_id = member.room_id
              and own_answer.player_id = member.player_id
          ) <> completed_room.question_count
      )
      and not exists (
        select 1
        from public.room_players scored_player
        where scored_player.room_id = completed_room.id
          and scored_player.score <> (
            select coalesce(sum(scored_answer.points_awarded), 0)::integer
            from public.player_answers scored_answer
            where scored_answer.room_id = scored_player.room_id
              and scored_answer.player_id = scored_player.player_id
          )
      )
    order by completed_room.id
    for update of completed_room
  loop
    for v_remaining_player in
      select remaining.player_id
      from public.room_players remaining
      where remaining.room_id = v_completed_room.id
        and remaining.player_id <> v_user_id
        and not exists (
          select 1
          from public.room_result_receipts receipt
          where receipt.room_id = remaining.room_id
            and receipt.player_id = remaining.player_id
        )
    loop
      select jsonb_agg(
        jsonb_build_object(
          'player_id', case
            when rp.player_id = v_user_id then
              '00000000-0000-0000-0000-000000000000'::uuid
            else rp.player_id
          end,
          'display_name', case
            when rp.player_id = v_user_id then 'Hesabê jêbirî'
            else coalesce(nullif(trim(profile.display_name), ''), 'Hevrik')
          end,
          'final_score', rp.score,
          'final_streak', rp.streak
        ) order by rp.joined_at, rp.player_id
      )
      into v_players
      from public.room_players rp
      join public.profiles profile on profile.id = rp.player_id
      where rp.room_id = v_completed_room.id;

      select jsonb_agg(rq.question_id order by rq.question_index)
      into v_question_ids
      from public.room_questions rq
      where rq.room_id = v_completed_room.id;

      select jsonb_agg(
        jsonb_build_object(
          'question_id', rq.question_id,
          'question_index', rq.question_index,
          'selected_option', pa.selected_option,
          'correct_option', question.correct_option,
          'is_correct', pa.is_correct,
          'points_awarded', pa.points_awarded,
          'response_ms', pa.response_ms,
          'explanation', question.explanation,
          'explanation_ku', question.explanation_ku,
          'explanation_tr', question.explanation_tr
        ) order by rq.question_index
      )
      into v_answers
      from public.player_answers pa
      join public.room_questions rq
        on rq.room_id = pa.room_id and rq.question_id = pa.question_id
      join public.questions question on question.id = pa.question_id
      where pa.room_id = v_completed_room.id
        and pa.player_id = v_remaining_player.player_id;

      select case
        when min(rp.score) = max(rp.score) then null
        when (array_agg(
          rp.player_id order by rp.score desc, rp.player_id
        ))[1] = v_user_id then
          '00000000-0000-0000-0000-000000000000'::uuid
        else (array_agg(
          rp.player_id order by rp.score desc, rp.player_id
        ))[1]
      end
      into v_winner_id
      from public.room_players rp
      where rp.room_id = v_completed_room.id;

      insert into public.room_result_snapshots (
        room_id,
        player_id,
        payload,
        finished_at,
        room_created_at
      ) values (
        v_completed_room.id,
        v_remaining_player.player_id,
        jsonb_build_object(
          'room', jsonb_build_object(
            'id', v_completed_room.id,
            'code', v_completed_room.code,
            'host_id', case
              when v_completed_room.host_id = v_user_id then null
              else v_completed_room.host_id
            end,
            'category_name', v_completed_room.category_name,
            'question_count', v_completed_room.question_count,
            'seconds_per_question', coalesce(
              v_completed_room.seconds_per_question,
              30
            ),
            'status', 'finished',
            'current_question_index',
              v_completed_room.current_question_index
          ),
          'own_player_id', v_remaining_player.player_id,
          'players', v_players,
          'question_ids', v_question_ids,
          'answers', v_answers,
          'winner_id', v_winner_id,
          'ended_reason', v_completed_room.ended_reason,
          'forfeited_by', v_completed_room.forfeited_by,
          'finished_at', v_completed_room.finished_at
        ),
        v_completed_room.finished_at,
        v_completed_room.created_at
      )
      on conflict (room_id, player_id) do nothing;
    end loop;
  end loop;

  for v_room in
    select r.id, r.status, r.host_id
    from public.rooms r
    where r.status in ('lobby', 'active')
      and (
        r.host_id = v_user_id
        or exists (
          select 1
          from public.room_players rp
          where rp.room_id = r.id
            and rp.player_id = v_user_id
        )
      )
    order by r.id
    for update of r
  loop
    if v_room.status = 'active' then
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'account_deleted',
        forfeited_by = v_user_id
      where r.id = v_room.id;

      delete from public.matchmaking_queue mq
      where mq.room_id = v_room.id;
    elsif v_room.status = 'lobby'
          and v_room.host_id = v_user_id then
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'host_left',
        forfeited_by = null
      where r.id = v_room.id;

      delete from public.matchmaking_queue mq
      where mq.room_id = v_room.id;
    end if;
  end loop;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_user_id;

  delete from public.favorite_questions
  where player_id = v_user_id;

  delete from public.coin_transactions
  where player_id = v_user_id;

  if to_regclass('public.questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.questions')
         and attname = 'created_by'
         and not attisdropped
     ) then
    execute
      'update public.questions set created_by = null where created_by = $1'
      using v_user_id;
  end if;

  if to_regclass('public.suggested_questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.suggested_questions')
         and attname = 'reviewed_by'
         and not attisdropped
     ) then
    execute
      'update public.suggested_questions set reviewed_by = null '
      || 'where reviewed_by = $1'
      using v_user_id;
  end if;

  update public.question_reports
  set reporter_id = null
  where reporter_id = v_user_id;

  delete from public.player_answers
  where player_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = v_user_id::text;

  delete from auth.users
  where id = v_user_id;

  return json_build_object('deleted', true);
end;
$$;

revoke all on function public.delete_my_account()
  from public, anon, authenticated;
grant execute on function public.delete_my_account()
  to authenticated;

-- Eski temizlik görevi artık maç kanıtı silmez. Oda kilitleri UUID sırasıyla
-- alınır; başka bir işlemdeki oda atlanıp bir sonraki cron turuna bırakılır.
create or replace function public.cleanup_stale_rooms()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room record;
  v_on_time_ready_count integer;
  v_not_ready_player_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));

  for v_room in
    select
      r.id,
      r.status,
      r.client_ready_deadline,
      (
        r.status = 'active'
        and r.client_ready_deadline is not null
        and clock_timestamp() >= r.client_ready_deadline
        and exists (
          select 1
          from public.room_questions rq
          where rq.room_id = r.id
            and rq.question_index = coalesce(r.current_question_index, 0)
            and rq.started_at is null
        )
        and (
          select count(*)
          from public.room_players rp
          where rp.room_id = r.id
            and rp.quiz_ready_at is not null
            and rp.quiz_ready_at <= r.client_ready_deadline
        ) < 2
      ) as ready_deadline_expired
    from public.rooms r
    where (
      r.status = 'lobby'
      and r.created_at < now() - interval '24 hours'
    ) or (
      r.status = 'active'
      and (
        coalesce(r.started_at, r.created_at) < now() - interval '24 hours'
        or (
          r.client_ready_deadline is not null
          and clock_timestamp() >= r.client_ready_deadline
          and exists (
            select 1
            from public.room_questions rq
            where rq.room_id = r.id
              and rq.question_index = coalesce(r.current_question_index, 0)
              and rq.started_at is null
          )
          and (
            select count(*)
            from public.room_players rp
            where rp.room_id = r.id
              and rp.quiz_ready_at is not null
              and rp.quiz_ready_at <= r.client_ready_deadline
          ) < 2
        )
      )
    )
    order by r.id
    for update of r skip locked
  loop
    v_not_ready_player_id := null;

    if v_room.ready_deadline_expired then
      select count(*)::integer
      into v_on_time_ready_count
      from public.room_players rp
      where rp.room_id = v_room.id
        and rp.quiz_ready_at is not null
        and rp.quiz_ready_at <= v_room.client_ready_deadline;

      if v_on_time_ready_count = 1 then
        select rp.player_id into v_not_ready_player_id
        from public.room_players rp
        where rp.room_id = v_room.id
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
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'opponent_not_ready',
        forfeited_by = v_not_ready_player_id
      where r.id = v_room.id;
    else
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'stale_timeout',
        forfeited_by = null
      where r.id = v_room.id;
    end if;
  end loop;

  delete from public.matchmaking_queue mq
  where (
    mq.room_id is null
    and mq.joined_at < now() - interval '10 minutes'
  ) or exists (
    select 1
    from public.rooms terminal_room
    where terminal_room.id = mq.room_id
      and terminal_room.status not in ('lobby', 'active')
  );
end;
$$;

revoke all on function public.cleanup_stale_rooms()
  from public, anon, authenticated;

-- Eski istemci parametreleri imza uyumluluğu için kalır; ödülün bütün
-- girdileri sunucunun kilitli oda ve cevap kayıtlarından yeniden üretilir.
create or replace function public.claim_quiz_reward(
  p_room_id uuid default null,
  p_score integer default 0,
  p_correct_count integer default 0,
  p_best_streak integer default 0,
  p_total_questions integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_room_status text;
  v_room_ended_reason text;
  v_current_question_index integer;
  v_room_score integer;
  v_correct_count integer;
  v_total_questions integer;
  v_answer_count integer;
  v_amount integer;
  v_reason text;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_player_id::text, 0));

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  if p_room_id is null then
    return jsonb_build_object(
      'amount', 0,
      'verification_required', true
    );
  end if;

  select r.status, r.ended_reason, r.current_question_index
  into v_room_status, v_room_ended_reason, v_current_question_index
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id
   and rp.player_id = v_player_id
  where r.id = p_room_id
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  if v_room_status <> 'finished' then
    return jsonb_build_object('amount', 0, 'room_not_finished', true);
  end if;

  -- Forfeit, host/account ayrılması, stale cleanup ve ready timeout dahil
  -- tamamlanma dışındaki her terminal sebep kesin olarak sıfır ödüldür.
  if v_room_ended_reason is distinct from 'completed' then
    return jsonb_build_object(
      'amount', 0,
      'room_not_completed', true,
      'ended_reason', v_room_ended_reason
    );
  end if;

  select count(*)::integer into v_total_questions
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_total_questions < 1
     or coalesce(v_current_question_index, -1) < v_total_questions then
    return jsonb_build_object(
      'amount', 0,
      'room_progress_incomplete', true
    );
  end if;

  select
    count(*)::integer,
    count(*) filter (where pa.is_correct)::integer,
    coalesce(sum(pa.points_awarded), 0)::integer
  into v_answer_count, v_correct_count, v_room_score
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id
   and rq.question_id = pa.question_id
  where pa.room_id = p_room_id
    and pa.player_id = v_player_id;

  if v_answer_count <> v_total_questions then
    return jsonb_build_object('amount', 0, 'answers_incomplete', true);
  end if;

  v_reason := 'quiz_complete:room=' || p_room_id::text;
  select max(coin_tx.amount)::integer
  into v_amount
  from public.coin_transactions coin_tx
  where coin_tx.player_id = v_player_id
    and coin_tx.reason = v_reason;
  if v_amount is not null then
    -- İlk claim commit olduktan sonra sonuç ekranı açılmadan uygulama
    -- kapanabilir. Retry yeni coin yazmaz; fakat daha önce gerçekten
    -- yatırılan miktarı döndürür ki kurtarılan sonuç ekranı 0 göstermesin.
    return jsonb_build_object(
      'amount', v_amount,
      'already_claimed', true
    );
  end if;

  v_amount :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_room_score / 80);

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_amount, v_reason);

  return jsonb_build_object(
    'amount', v_amount,
    'already_claimed', false
  );
end;
$$;

revoke all on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) from public, anon, authenticated;
grant execute on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) to authenticated;

-- Yalnız reveal transactionları içinden çağrılan iç yardımcı. Puanı ve mevcut
-- seriyi cevap kayıtlarından baştan üretir; aynı soru için tekrar çağrılması
-- sonucu değiştirmez ve ilk tek cevapla çalışmayı açıkça reddeder.
create or replace function public.recalculate_room_player_scores(
  p_room_id uuid,
  p_question_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question_index integer;
  v_player_count integer;
  v_answer_count integer;
begin
  select rq.question_index
  into v_question_index
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_id = p_question_id
    and rq.revealed_at is not null;

  if not found then
    raise exception 'Question is not revealed';
  end if;

  select count(*)::integer
  into v_player_count
  from public.room_players rp
  where rp.room_id = p_room_id;

  select count(distinct pa.player_id)::integer
  into v_answer_count
  from public.player_answers pa
  join public.room_players rp
    on rp.room_id = pa.room_id and rp.player_id = pa.player_id
  where pa.room_id = p_room_id
    and pa.question_id = p_question_id;

  if v_player_count <> 2 or v_answer_count <> 2 then
    raise exception 'Exactly two answers are required to finalize scores';
  end if;

  with per_player as (
    select
      member.player_id,
      coalesce(sum(answer.points_awarded), 0)::integer as score,
      coalesce(
        max(rq.question_index) filter (where answer.is_correct is false),
        -1
      )::integer as last_wrong_index
    from public.room_players member
    left join public.room_questions rq
      on rq.room_id = member.room_id
      and rq.question_index <= v_question_index
    left join public.player_answers answer
      on answer.room_id = rq.room_id
      and answer.question_id = rq.question_id
      and answer.player_id = member.player_id
    where member.room_id = p_room_id
    group by member.player_id
  ), recalculated as (
    select
      stats.player_id,
      stats.score,
      count(answer.question_id) filter (
        where answer.is_correct
          and rq.question_index > stats.last_wrong_index
      )::integer as streak
    from per_player stats
    left join public.room_questions rq
      on rq.room_id = p_room_id
      and rq.question_index <= v_question_index
    left join public.player_answers answer
      on answer.room_id = rq.room_id
      and answer.question_id = rq.question_id
      and answer.player_id = stats.player_id
    group by stats.player_id, stats.score, stats.last_wrong_index
  )
  update public.room_players rp
  set
    score = recalculated.score,
    streak = recalculated.streak
  from recalculated
  where rp.room_id = p_room_id
    and rp.player_id = recalculated.player_id;
end;
$$;

revoke all on function public.recalculate_room_player_scores(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.get_my_resumable_room()
returns json
language plpgsql
security definer
set search_path = public
as $$
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
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  left join public.categories c on c.id = r.category_id
  where rp.player_id = v_uid
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
$$;

revoke all on function public.get_my_resumable_room() from public, anon;
grant execute on function public.get_my_resumable_room() to authenticated;

-- Yalnız eksiksiz tamamlanmış ve henüz kullanıcı tarafından onaylanmamış
-- en yeni maç döner. Rakibin seçili cevapları hiçbir JSON dalına eklenmez.
create or replace function public.get_room_result_payload(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_players jsonb;
  v_question_ids jsonb;
  v_answers jsonb;
  v_winner_id uuid;
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
    coalesce(c.name, 'Ziman') as category_name
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
    and coalesce(r.current_question_index, -1) = r.question_count
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = r.id
        and receipt.player_id = v_uid
    )
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

  select case
    when min(rp.score) = max(rp.score) then null
    else (array_agg(rp.player_id order by rp.score desc, rp.player_id))[1]
  end
  into v_winner_id
  from public.room_players rp
  where rp.room_id = v_room.id;

  return json_build_object(
    'room', json_build_object(
      'id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'category_name', v_room.category_name,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'status', 'finished',
      'current_question_index', v_room.current_question_index
    ),
    'own_player_id', v_uid,
    'players', v_players,
    'question_ids', v_question_ids,
    'answers', v_answers,
    'winner_id', v_winner_id,
    'ended_reason', v_room.ended_reason,
    'forfeited_by', v_room.forfeited_by,
    'finished_at', v_room.finished_at
  );
end;
$$;

revoke all on function public.get_room_result_payload(uuid)
  from public, anon, authenticated;

create or replace function public.get_my_room_result(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_room_id is null then
    raise exception 'Room id is required';
  end if;
  return public.get_room_result_payload(p_room_id);
end;
$$;

revoke all on function public.get_my_room_result(uuid) from public, anon;
grant execute on function public.get_my_room_result(uuid) to authenticated;

create or replace function public.get_my_pending_room_result()
returns json
language sql
security definer
set search_path = public
as $$
  select public.get_room_result_payload(null);
$$;

revoke all on function public.get_my_pending_room_result()
  from public, anon;
grant execute on function public.get_my_pending_room_result()
  to authenticated;

create or replace function public.acknowledge_room_result(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_question_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- İlk çağrı commit olup ağ yanıtı kaybolmuş olabilir. Makbuz zaten varsa
  -- kanıt satırları daha sonra anonimleştirilmiş/silinmiş olsa bile aynı
  -- başarılı sonucu döndür; idempotent retry yeniden tamlık aramamalıdır.
  if exists (
    select 1
    from public.room_result_receipts receipt
    where receipt.room_id = p_room_id
      and receipt.player_id = v_uid
  ) then
    return json_build_object('acknowledged', true, 'room_id', p_room_id);
  end if;

  -- Hesap silme öncesi güvenilir fonksiyonun ürettiği immutable snapshot,
  -- silinen rakibin kişisel satırları artık bulunmasa da aynı tamlık kanıtıdır.
  if exists (
    select 1
    from public.room_result_snapshots saved_result
    join public.room_players saved_member
      on saved_member.room_id = saved_result.room_id
      and saved_member.player_id = saved_result.player_id
    join public.rooms saved_room on saved_room.id = saved_result.room_id
    where saved_result.room_id = p_room_id
      and saved_result.player_id = v_uid
      and saved_room.status = 'finished'
      and saved_room.ended_reason = 'completed'
      and saved_result.payload ->> 'own_player_id' = v_uid::text
      and saved_result.payload ->> 'ended_reason' = 'completed'
      and saved_result.payload -> 'room' ->> 'id' = p_room_id::text
      and saved_result.payload -> 'room' ->> 'status' = 'finished'
      and (
        saved_result.payload -> 'room' ->> 'current_question_index'
      )::integer = (
        saved_result.payload -> 'room' ->> 'question_count'
      )::integer
      and jsonb_array_length(saved_result.payload -> 'players') = 2
      and jsonb_array_length(saved_result.payload -> 'question_ids') = (
        saved_result.payload -> 'room' ->> 'question_count'
      )::integer
      and jsonb_array_length(saved_result.payload -> 'answers') = (
        saved_result.payload -> 'room' ->> 'question_count'
      )::integer
  ) then
    insert into public.room_result_receipts (room_id, player_id)
    values (p_room_id, v_uid)
    on conflict (room_id, player_id) do nothing;

    return json_build_object('acknowledged', true, 'room_id', p_room_id);
  end if;

  select r.question_count
  into v_question_count
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
    and r.status = 'finished'
    and r.ended_reason = 'completed'
    and r.forfeited_by is null
    and r.finished_at is not null
    and r.question_count > 0
    and coalesce(r.current_question_index, -1) = r.question_count
  for share of r;

  if not found then
    raise exception 'Completed room result is unavailable';
  end if;

  if not exists (
    select 1
    from public.room_players exact_players
    where exact_players.room_id = p_room_id
    having count(*) = 2
  ) or not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
    having count(*) = v_question_count
      and count(distinct rq.question_index) = v_question_count
      and min(rq.question_index) = 0
      and max(rq.question_index) = v_question_count - 1
      and bool_and(rq.revealed_at is not null)
  ) or not exists (
    select 1
    from public.player_answers pa
    join public.room_questions answered_question
      on answered_question.room_id = pa.room_id
      and answered_question.question_id = pa.question_id
    join public.room_players answering_player
      on answering_player.room_id = pa.room_id
      and answering_player.player_id = pa.player_id
    where pa.room_id = p_room_id
    having count(*) = v_question_count * 2
  ) or exists (
    select 1
    from public.room_players member
    where member.room_id = p_room_id
      and (
        select count(*)
        from public.player_answers own_answer
        join public.room_questions own_question
          on own_question.room_id = own_answer.room_id
          and own_question.question_id = own_answer.question_id
        where own_answer.room_id = member.room_id
          and own_answer.player_id = member.player_id
      ) <> v_question_count
  ) or exists (
    select 1
    from public.room_players scored_player
    where scored_player.room_id = p_room_id
      and scored_player.score <> (
        select coalesce(sum(scored_answer.points_awarded), 0)::integer
        from public.player_answers scored_answer
        where scored_answer.room_id = scored_player.room_id
          and scored_answer.player_id = scored_player.player_id
      )
  ) then
    raise exception 'Completed room result is incomplete';
  end if;

  insert into public.room_result_receipts (room_id, player_id)
  values (p_room_id, v_uid)
  on conflict (room_id, player_id) do nothing;

  return json_build_object('acknowledged', true, 'room_id', p_room_id);
end;
$$;

revoke all on function public.acknowledge_room_result(uuid)
  from public, anon;
grant execute on function public.acknowledge_room_result(uuid)
  to authenticated;

drop function if exists public.advance_room_question(uuid);

create or replace function public.advance_room_question(
  p_room_id uuid,
  p_expected_question_index integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_count integer;
  v_current_question_index integer;
  v_next integer;
  v_question_id uuid;
  v_answer_count integer;
  v_server_now timestamp with time zone;
  v_question_started_at timestamp with time zone;
  v_revealed_at timestamp with time zone;
  v_deadline timestamp with time zone;
  v_limit_ms integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  v_current_question_index := coalesce(v_room.current_question_index, 0);

  -- Terminal ilerletmenin cevabı kaybolursa iki üyeden herhangi biri aynı
  -- CAS isteğini güvenle tekrarlayabilir.
  if v_room.status = 'finished' then
    return v_current_question_index;
  end if;

  if v_room.status <> 'active' then
    raise exception 'Room is not active';
  end if;

  if p_expected_question_index is null then
    raise exception 'Expected question index is required';
  end if;

  select count(*)::integer into v_count
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_count < 1 then
    raise exception 'Room has no questions';
  end if;

  -- Eski sürümden terminal indexte aktif kalmış oda da ilk güvenli çağrıda
  -- atomik biçimde kapanır.
  if v_current_question_index >= v_count then
    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, clock_timestamp()),
      ended_reason = 'completed',
      forfeited_by = null
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;
    return v_current_question_index;
  end if;

  if p_expected_question_index < v_current_question_index then
    return v_current_question_index;
  end if;

  if p_expected_question_index > v_current_question_index then
    raise exception 'Expected question index is ahead of the room';
  end if;

  select rq.question_id, rq.started_at, rq.revealed_at
  into v_question_id, v_question_started_at, v_revealed_at
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_index = v_current_question_index;

  if not found then
    raise exception 'Current room question is missing';
  end if;

  if v_question_started_at is null then
    raise exception 'Room clients are not ready';
  end if;

  v_server_now := clock_timestamp();
  v_limit_ms := greatest(
    1,
    coalesce(v_room.seconds_per_question, 20)
  ) * 1000;
  v_deadline := v_question_started_at + make_interval(
    secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
  );

  select count(distinct pa.player_id)::integer
  into v_answer_count
  from public.player_answers pa
  join public.room_players rp
    on rp.room_id = pa.room_id and rp.player_id = pa.player_id
  where pa.room_id = p_room_id
    and pa.question_id = v_question_id;

  -- İlk tamamlayıcı çağrı yalnız sonucu reveal eder. Deadline'da eksik cevap
  -- sunucu TIMEOUT'u olarak aynı transactionda doldurulur; skor/seri iki
  -- oyuncu için cevap kayıtlarından idempotent biçimde yeniden hesaplanır.
  if v_revealed_at is null then
    if v_answer_count <> 2 and v_server_now < v_deadline then
      raise exception 'Current question is not complete';
    end if;

    if v_answer_count <> 2 and v_server_now >= v_deadline then
      insert into public.player_answers (
        room_id,
        question_id,
        player_id,
        selected_option,
        is_correct,
        response_ms,
        points_awarded
      )
      select
        p_room_id,
        v_question_id,
        rp.player_id,
        'TIMEOUT',
        false,
        v_limit_ms,
        0
      from public.room_players rp
      where rp.room_id = p_room_id
        and not exists (
          select 1
          from public.player_answers existing_answer
          where existing_answer.room_id = p_room_id
            and existing_answer.question_id = v_question_id
            and existing_answer.player_id = rp.player_id
        )
      on conflict do nothing;

      select count(distinct pa.player_id)::integer
      into v_answer_count
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.player_id = pa.player_id
      where pa.room_id = p_room_id
        and pa.question_id = v_question_id;
    end if;

    if v_answer_count <> 2 then
      raise exception 'Current question answer invariant failed';
    end if;

    update public.room_questions rq
    set revealed_at = coalesce(rq.revealed_at, v_server_now)
    where rq.room_id = p_room_id
      and rq.question_index = v_current_question_index
    returning rq.revealed_at into v_revealed_at;

    perform public.recalculate_room_player_scores(
      p_room_id,
      v_question_id
    );

    -- Zorunlu sonuç görünümü başlamadan indeks artırılmaz.
    return v_current_question_index;
  end if;

  if v_answer_count <> 2 then
    raise exception 'Revealed question answer invariant failed';
  end if;

  -- İki istemci de sonucu en az beş saniye görebilsin. Erken retry hata değil,
  -- mevcut indeks cevabıdır; böylece ağ tekrarı idempotent kalır.
  if v_server_now < v_revealed_at + interval '5 seconds' then
    return v_current_question_index;
  end if;

  v_next := v_current_question_index + 1;

  update public.rooms r
  set current_question_index = v_next
  where r.id = p_room_id
    and coalesce(r.current_question_index, 0) = p_expected_question_index;

  if not found then
    raise exception 'Room question index changed unexpectedly';
  end if;

  if v_next < v_count then
    update public.room_questions rq
    set
      started_at = coalesce(rq.started_at, v_server_now),
      revealed_at = null
    where rq.room_id = p_room_id
      and rq.question_index = v_next;

    if not found then
      raise exception 'Next room question is missing';
    end if;
  else
    -- Terminal indeks ve bitiş aynı oda kilidi/transaction içindedir. Süreç
    -- bu noktada ölse bile yeniden açılış aktif index=count görmez.
    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, v_server_now),
      ended_reason = 'completed',
      forfeited_by = null
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;
  end if;

  return v_next;
end;
$$;

revoke all on function public.advance_room_question(uuid, integer)
  from public, anon;
grant execute on function public.advance_room_question(uuid, integer)
  to authenticated;

create or replace function public.submit_answer(
  p_room_id uuid,
  p_question_id uuid,
  p_selected_option text,
  p_response_ms integer default 2000
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_received_at timestamp with time zone := clock_timestamp();
  v_room public.rooms%rowtype;
  v_is_correct boolean;
  v_correct_option text;
  v_explanation text;
  v_explanation_ku text;
  v_explanation_tr text;
  v_question_index integer;
  v_question_started_at timestamp with time zone;
  v_revealed_at timestamp with time zone;
  v_deadline timestamp with time zone;
  v_elapsed_ms bigint;
  v_limit_ms integer;
  v_response_ms integer;
  v_points integer := 0;
  v_answer_streak integer := 0;
  v_remaining_ratio numeric;
  v_current_streak integer;
  v_current_score integer;
  v_answer_count integer := 0;
  v_already_answered boolean := false;
  v_revealable boolean := false;
  v_existing_answer record;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  p_selected_option := upper(
    coalesce(nullif(trim(p_selected_option), ''), 'TIMEOUT')
  );
  if p_selected_option not in ('A', 'B', 'C', 'D', 'TIMEOUT') then
    raise exception 'Invalid option';
  end if;

  -- `p_response_ms` yalnız eski istemci imza uyumluluğu için kalır; kayıt ve
  -- puan sunucunun soru başlangıcı ile çağrıyı aldığı andan hesaplanır.
  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  select rp.score, rp.streak
  into v_current_score, v_current_streak
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.player_id = v_uid
  for update;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select
    rq.question_index,
    rq.started_at,
    rq.revealed_at,
    q.correct_option,
    q.explanation,
    q.explanation_ku,
    q.explanation_tr
  into
    v_question_index,
    v_question_started_at,
    v_revealed_at,
    v_correct_option,
    v_explanation,
    v_explanation_ku,
    v_explanation_tr
  from public.room_questions rq
  join public.questions q on q.id = rq.question_id
  where rq.room_id = p_room_id
    and rq.question_id = p_question_id;

  if not found then
    raise exception 'Question is not in this room';
  end if;

  v_limit_ms := greatest(
    1,
    coalesce(v_room.seconds_per_question, 20)
  ) * 1000;
  if v_question_started_at is not null then
    v_deadline := v_question_started_at
      + make_interval(
        secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
      );
  end if;

  -- Duplicate istek önce mevcut satırı yükler. Seçim parametresi farklı gelse
  -- bile kayıt değiştirilmez; pending/full görünürlük kararı yeniden yapılır.
  select
    pa.selected_option,
    pa.is_correct,
    pa.points_awarded,
    pa.response_ms
  into v_existing_answer
  from public.player_answers pa
  where pa.room_id = p_room_id
    and pa.question_id = p_question_id
    and pa.player_id = v_uid;

  if found then
    p_selected_option := v_existing_answer.selected_option;
    v_is_correct := v_existing_answer.is_correct;
    v_points := v_existing_answer.points_awarded;
    v_response_ms := v_existing_answer.response_ms;
    v_already_answered := true;
  else
    if v_room.status <> 'active' then
      raise exception 'Room is not active';
    end if;

    if v_question_index <> coalesce(v_room.current_question_index, 0) then
      raise exception 'Question is not the current active room question';
    end if;

    if v_question_started_at is null then
      raise exception 'Room clients are not ready';
    end if;

    -- Çağrı oda kilidini beklerken başka transaction soruyu başlatmışsa
    -- alınma zamanı started_at'ten eski olabilir. Bunu 0 ms'e sıkıştırmak
    -- azami hız puanı üretirdi; başlangıç öncesi cevap açıkça geçersizdir.
    if v_received_at < v_question_started_at then
      raise exception 'Answer received before question started';
    end if;

    v_elapsed_ms := floor(
      extract(epoch from (v_received_at - v_question_started_at)) * 1000
    )::bigint;
    v_response_ms := least(
      v_limit_ms::bigint,
      v_elapsed_ms
    )::integer;

    if v_received_at >= v_deadline then
      p_selected_option := 'TIMEOUT';
    end if;

    v_is_correct := p_selected_option <> 'TIMEOUT'
      and p_selected_option = v_correct_option;
    if v_is_correct then
      v_answer_streak := v_current_streak + 1;
      v_remaining_ratio := greatest(
        0,
        (v_limit_ms - v_response_ms)::numeric / v_limit_ms
      );
      v_points := 100
        + round(v_remaining_ratio * 100)::integer
        + least(v_answer_streak * 10, 50);
    else
      v_answer_streak := 0;
      v_points := 0;
    end if;

    insert into public.player_answers (
      room_id,
      question_id,
      player_id,
      selected_option,
      is_correct,
      response_ms,
      points_awarded
    ) values (
      p_room_id,
      p_question_id,
      v_uid,
      p_selected_option,
      v_is_correct,
      v_response_ms,
      v_points
    );
  end if;

  v_revealable := v_question_index < coalesce(v_room.current_question_index, 0)
    or v_revealed_at is not null;

  -- Aktif/current soru ikinci cevapla veya sunucu deadline'ıyla finalize olur.
  -- İlk cevap room_players skor/serisini değiştirmez ve aşağıdaki güvenli
  -- pending gövdesinden başka sonuç alanı döndürmez.
  if v_revealable = false
     and v_room.status = 'active'
     and v_question_index = coalesce(v_room.current_question_index, 0) then
    select count(distinct pa.player_id)::integer
    into v_answer_count
    from public.player_answers pa
    join public.room_players rp
      on rp.room_id = pa.room_id and rp.player_id = pa.player_id
    where pa.room_id = p_room_id
      and pa.question_id = p_question_id;

    if v_answer_count <> 2
       and v_deadline is not null
       and v_received_at >= v_deadline then
      insert into public.player_answers (
        room_id,
        question_id,
        player_id,
        selected_option,
        is_correct,
        response_ms,
        points_awarded
      )
      select
        p_room_id,
        p_question_id,
        rp.player_id,
        'TIMEOUT',
        false,
        v_limit_ms,
        0
      from public.room_players rp
      where rp.room_id = p_room_id
        and not exists (
          select 1
          from public.player_answers existing_answer
          where existing_answer.room_id = p_room_id
            and existing_answer.question_id = p_question_id
            and existing_answer.player_id = rp.player_id
        )
      on conflict do nothing;

      select count(distinct pa.player_id)::integer
      into v_answer_count
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.player_id = pa.player_id
      where pa.room_id = p_room_id
        and pa.question_id = p_question_id;
    end if;

    if v_answer_count > 2 then
      raise exception 'Current question answer invariant failed';
    end if;

    if v_answer_count = 2 then
      update public.room_questions rq
      set revealed_at = coalesce(rq.revealed_at, v_received_at)
      where rq.room_id = p_room_id
        and rq.question_id = p_question_id
      returning rq.revealed_at into v_revealed_at;

      perform public.recalculate_room_player_scores(
        p_room_id,
        p_question_id
      );
      v_revealable := true;
    end if;
  end if;

  if not v_revealable then
    return json_build_object(
      'accepted', true,
      'pending', true,
      'selected_option', p_selected_option,
      'response_ms', v_response_ms,
      'already_answered', v_already_answered
    );
  end if;

  -- Reveal transactionı score/streak'i iki üye için birlikte güncelledi.
  select rp.score, rp.streak
  into v_current_score, v_current_streak
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  return json_build_object(
    'accepted', true,
    'pending', false,
    'selected_option', p_selected_option,
    'is_correct', v_is_correct,
    'points', v_points,
    'new_score', v_current_score,
    'new_streak', v_current_streak,
    'response_ms', v_response_ms,
    'correct_option', v_correct_option,
    'explanation', v_explanation,
    'explanation_ku', v_explanation_ku,
    'explanation_tr', v_explanation_tr,
    'already_answered', v_already_answered
  );
end;
$$;

revoke all on function public.submit_answer(uuid, uuid, text, integer)
  from public, anon;
grant execute on function public.submit_answer(uuid, uuid, text, integer)
  to authenticated;

-- ── Cutover: uçuştaki maçları kurtar ────────────────────────────────────
--
-- Bu göç "aktif odanın güncel sorusunda `started_at` DOLUDUR" invariant'ını
-- getiriyor: `submit_answer` ve `advance_room_question` boşsa reddediyor.
-- Ama YAYINDAKİ kod bu invariant'ı 0. sorunun ötesinde hiç kurmuyor —
-- `start_room_game` yalnız ilk satıra `started_at` yazıyor, yayındaki
-- `advance_room_question(uuid)` `room_questions`a hiç dokunmuyor.
--
-- Yani `commit` anında, 1. soruya geçmiş her aktif maç anında kilitleniyor:
-- iki güncel istemci varsa `mark_room_client_ready` ile timer sıfırlanarak
-- kurtuluyor, karışık odada rakip ~2 dakika sonra hükmen kaybediyor, iki
-- eski istemcili oda 24 saatlik süpürmeye kadar asılı kalıyor. Hiçbiri
-- kabul edilebilir değil ve hiçbiri kullanıcının hatası değil.
--
-- Tek satırlık geri dolgu bunu kaynağında kaldırır: yalnız EKSİK olanı
-- doldurur (`is null` koruması), dolu olanı ellemez, bu yüzden yeniden
-- çalıştırmak güvenlidir.
update public.room_questions rq
set started_at = clock_timestamp()
from public.rooms r
where r.id = rq.room_id
  and r.status = 'active'
  and rq.question_index = coalesce(r.current_question_index, 0)
  and rq.started_at is null;

-- ── Postflight: sessiz aşırı yükleme bırakma ────────────────────────────
--
-- Yukarıdaki `drop function if exists` çağrıları argüman TİPİNE göre eşleşir.
-- Canlıdaki tanım farklı tiplerle duruyorsa düşürme sessizce boşa gider ve
-- `create or replace` İKİNCİ bir aşırı yükleme kurar. Sonuç bir hata değil,
-- daha kötüsü: PostgREST çağrıyı belirsiz bulup `PGRST203` döndürür ve oda
-- kurma canlıda ölür. Belirsizliği yayına taşımak yerine burada patlat.
do $$
declare
  v_name text;
  v_count integer;
begin
  foreach v_name in array array[
    'create_online_room', 'join_room_by_code', 'set_room_ready',
    'start_room_game', 'mark_room_client_ready', 'join_matchmaking',
    'cancel_matchmaking', 'finish_room_game', 'leave_room',
    'delete_my_account', 'claim_quiz_reward', 'get_my_resumable_room',
    'get_my_room_result', 'get_my_pending_room_result',
    'acknowledge_room_result', 'advance_room_question', 'submit_answer'
  ] loop
    select count(*) into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = v_name;

    if v_count <> 1 then
      raise exception
        'public.% has % definitions after this migration; expected exactly 1',
        v_name, v_count;
    end if;
  end loop;
end $$;

commit;
