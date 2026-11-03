-- Ölçek sertleştirme (10.000 eşzamanlı kullanıcı denetimi, 2026-11-04).
-- Canlıda (2026-11-04/05, applied.md ✅). Geri alma: geri_al/2026-11-04_olcek_sertlestirme_geri.sql
--
-- Dayanak (canlı ✅ tanımlar; gövdeler uygulama anında pg_get_functiondef ile
-- okunup yalnız bağlayıcı metin değiştirilir, bağlayıcı bulunamazsa göç durur):
--   * get_leaderboard / get_my_leaderboard_rank / get_friends_leaderboard:
--     2026-11-03_siralama_t1.sql
--   * create_online_room_impl: 2026-10-31_room_limits.sql
--   * join_room_by_code: 2026-10-29_codex_denetim_duzeltmeleri.sql
--   * join_matchmaking: 2026-10-18_oda_kod_kategori.sql
--   * cleanup_stale_rooms: 2026-10-24_sunucu_sertlestirme.sql
--   * delete_my_account: 2026-10-16_kalabalik_oda.sql
--   * create_room_rematch: 2026-11-03_rovans_oda_sahibi.sql
--   * invite_friends_to_room: 2026-11-01_davet_ret_korumasi.sql
--   * add_friend: 2026-10-15_sosyal_ve_sertlestirme.sql
--   * limit_suggested_question_rate: 2026-11-01_oneri_siniri.sql
--   * room_messages_member_select politikası: 2026-08-01_room_messages_policy_hardening.sql
--   * wake_push_delivery_v2: 2026-10-31_push_delivery_v2.sql
--
-- 1. SIRALAMA: üç işlev her çağrıda BÜTÜN bitmiş odaları (room_players x rooms)
--    tarıyordu; "tüm zamanlar" oyuncu ve oda sayısıyla doğrusal yavaşlar.
--    Bakımı yapılan günlük toplam tablosu `player_score_daily` (oyuncu x
--    İstanbul günü) rooms tetikleyicisiyle güncellenir; işlevler onu okur.
--    Çıktı biçimi ve anlam AYNI: günlük tavan yok, İstanbul günü, aynı
--    `p_days` penceresi (kayan `now() - N gün`; yalnız kısmi SINIR günü ham
--    satırdan hesaplanır, böylece pencere eskisiyle bire bir kalır).
-- 2. ODA ÜYELİĞİ KİLİDİ: tek global `room-membership` kilidi her oda kurma /
--    katılma / eşleşme çağrısını TÜM kullanıcılar arasında sıraya diziyordu.
--    Kullanıcı başına kilide ('room-membership:' || uid) indirildi. "Kullanıcı
--    başına tek canlı oda" kuralı zaten bu kullanıcının kilidi + profil satır
--    kilidi altında denetleniyordu; kapasite denetimi oda satırı kilidiyle
--    (for update of r) korunur. Eşleşmede rakibin kilidi bloklamadan denenir
--    (pg_try_advisory_xact_lock): alınamazsa bu çağrı bekleme kuyruğuna girer,
--    ölümcül kilitlenme olmaz.
-- 3. HIZ SINIRLARI: oda kurma 30/saat, arkadaş ekleme çağrısı 50/saat
--    (`rate_limit_hit`); davet ve soru önerisi sayımları sayım+eklemeden ÖNCE
--    kullanıcı başına advisory kilitle yarışa karşı güvenli.
-- 4. RLS: room_messages üye SELECT politikasında auth.uid() satır başına değil
--    bir kez hesaplanır ((select auth.uid())); destekleyici indeksler.
-- 5. PUSH: tetikleyiciden gelen uyandırma 2 sn içinde ikinci kez gönderilmez
--    (config satırında last_wake_at). Edge işlevi (send-push) paket paket
--    boşaltır; dağıtımı ana ajan yapar.
--
-- KİLİT SIRASI (bütün işlevlerde AYNI; tersi ölümcül kilitlenme üretir):
--   1) kullanıcı kilidi  'room-membership:' || uid   (çağıranın kendi kilidi)
--   2) matchmaking:<kategori> kilidi (yalnız eşleşme)
--   3) rakip kullanıcı kilidi — YALNIZ pg_try (asla bekleme)
--   4) oda satırı kilitleri (for update / for share), id sırasıyla
--   5) yaprak kilitler: rate:<kova>:<uid>, invite:<uid>, suggest:<uid>,
--      score-daily:<oyuncu>:<gün> (hiçbiri başka kilit beklemez)
--   create_room_rematch eskiden kaynak odayı for update ile kilitleyip SONRA
--   üyelik kilidini alıyordu; delete_my_account ise önce kullanıcı kilidini
--   alır → ters sıra. Rövanş artık kullanıcı kilidini ilk iş olarak alır.
--
-- SIRALAMA TOPLAMI TUTARLILIK ŞEMASI (kanıt taslağı):
--   * Tetikleyici ARTIRMAZ; (oyuncu, gün) çiftini HAM satırdan yeniden hesaplar
--     ve upsert eder (idempotent). Aynı çift için eşzamanlı iki hesaplama
--     'score-daily:<oyuncu>:<gün>' advisory kilidiyle sıralanır; kilidi alan
--     ikinci hesaplama kilit alındıktan SONRA başlayan sorguyla (read committed
--     yeni anlık görüntü) birincinin işlenmiş verisini görür → kayıp güncelleme yok.
--   * rooms üzerinde tablo düzeyi SHARE kilidi YOKTUR. Geri doldurma kilitsiz
--     toplu upsert (on conflict do nothing: var olan satır tetikleyicinin taze
--     değeridir) olarak ÖNCE çalışır. create trigger rooms üzerinde kısa bir
--     SHARE ROW EXCLUSIVE kilidi alır ve işlem sonuna dek tutar; bu kilit
--     altında, geri doldurma başlangıcından bu yana bitmiş odaların
--     (oyuncu, gün) çiftleri ham satırdan yeniden hesaplanır. Kilit tutulurken
--     rooms'a yazılamadığından yakalama sorgusu kesin bir kesit görür; kilit
--     açıldığında (commit) tetikleyici artık görünürdür → aradaki boşluk
--     (geri doldurma anlık görüntüsü ↔ tetikleyici görünürlüğü) kapanır.
--   * finished_at boş bitmiş odalar eski bitişik-süzgeçte yalnız "tüm zamanlar"a
--     girerdi (finished_at >= now() - N gün bunları dışlar). Toplamda bu odalar
--     day = '-infinity' kovasında tutulur: p_days <= 0 hepsini, p_days > 0
--     (a.day > sınır günü) hiçbirini görmez.
-- İNDEKS: rooms üzerinde indeks BU göçte yoktur (create index rooms yazmalarını
--   bloklar). Büyük canlı veritabanı için ayrı dosya:
--   2026-11-04_olcek_indeks_concurrently.sql (transaction DIŞINDA koşulur).
--   room_messages (room_id, created_at) göçte kalır: küçük tablo (canlı ~100
--   profil); büyürse aynı dosyadaki CONCURRENTLY sürümünü kullan.
begin;

set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------
-- Ön koşullar
-- ---------------------------------------------------------------------------
do $olcek_onkosul$
begin
  if to_regprocedure('public.get_leaderboard(integer,integer)') is null
     or to_regprocedure('public.get_my_leaderboard_rank(integer)') is null
     or to_regprocedure('public.get_friends_leaderboard(integer)') is null
     or to_regprocedure('public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)') is null
     or to_regprocedure('public.join_room_by_code(text)') is null
     or to_regprocedure('public.join_matchmaking(text)') is null
     or to_regprocedure('public.cleanup_stale_rooms()') is null
     or to_regprocedure('public.delete_my_account()') is null
     or to_regprocedure('public.create_room_rematch(uuid)') is null
     or to_regprocedure('public.invite_friends_to_room(uuid,uuid[])') is null
     or to_regprocedure('public.add_friend(uuid,text)') is null
     or to_regprocedure('public.wake_push_delivery_v2()') is null
     or to_regclass('public.push_delivery_v2_config') is null then
    raise exception 'olcek: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
end;
$olcek_onkosul$;

-- Bağlayıcı metin yamacı: canlı gövdeyi okur, bağlayıcı TAM BİR kez bulunursa
-- değiştirir. Yeni metin zaten varsa dokunmaz (idempotent).
create or replace function pg_temp.olcek_yama(p_imza text, p_eski text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_def text;
  v_adet integer;
begin
  v_def := pg_get_functiondef(to_regprocedure(p_imza));
  if v_def is null then
    raise exception 'olcek: işlev yok: %', p_imza;
  end if;
  if position(p_yeni in v_def) > 0 then
    return;
  end if;
  v_adet := (length(v_def) - length(replace(v_def, p_eski, ''))) / length(p_eski);
  if v_adet <> 1 then
    raise exception 'olcek: % için bağlayıcı metin % kez bulundu (1 beklenir); canlı gövde değişmiş, yeniden incele', p_imza, v_adet;
  end if;
  execute replace(v_def, p_eski, p_yeni);
end;
$yama$;

-- ---------------------------------------------------------------------------
-- 3a. Genel hız sınırı yardımcısı + olay tablosu
-- ---------------------------------------------------------------------------
create table if not exists public.rate_limit_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  created_at timestamptz not null default now()
);
create index if not exists rate_limit_events_user_bucket_idx
  on public.rate_limit_events (user_id, bucket, created_at);
alter table public.rate_limit_events enable row level security;
revoke all on public.rate_limit_events from public, anon, authenticated;

-- true = izin verildi (olay kaydedildi), false = sınır aşıldı. auth.uid() yoksa
-- (service_role / bakım betiği) sınır uygulanmaz. Sayım+ekleme kullanıcı+kova
-- başına advisory kilitle sıralanır; kilit işlem sonuna dek tutulur.
create or replace function public.rate_limit_hit(
  p_bucket text,
  p_limit integer,
  p_window interval default interval '1 hour'
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    return true;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('rate:' || p_bucket || ':' || v_uid::text, 0));

  delete from public.rate_limit_events e
  where e.user_id = v_uid
    and e.bucket = p_bucket
    and e.created_at <= now() - p_window;

  select count(*)::integer into v_count
  from public.rate_limit_events e
  where e.user_id = v_uid
    and e.bucket = p_bucket;

  if v_count >= p_limit then
    return false;
  end if;

  insert into public.rate_limit_events (user_id, bucket) values (v_uid, p_bucket);
  return true;
end;
$function$;
revoke all on function public.rate_limit_hit(text, integer, interval)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2 + 3b. Oda üyeliği kilidi: global -> kullanıcı başına; oda kurma sınırı
-- ---------------------------------------------------------------------------
select pg_temp.olcek_yama(
  'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$,
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_uid::text, 0));$y$);

-- Hız sınırı, "mevcut canlı oda varsa onu dön" dalından SONRA: ağ tekrarı ya
-- da çift dokunuş yeni oda üretmez ve sayıma girmez.
select pg_temp.olcek_yama(
  'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  E'  loop\n    v_attempt := v_attempt + 1;',
  E'  -- Saatte en çok 30 yeni oda (2026-11-04 ölçek sertleştirme).\n'
  '  if not public.rate_limit_hit(''room_create'', 30, interval ''1 hour'') then\n'
  '    raise exception ''Too many rooms created'' using errcode = ''ZK429'';\n'
  '  end if;\n\n'
  '  loop\n    v_attempt := v_attempt + 1;');

select pg_temp.olcek_yama(
  'public.join_room_by_code(text)',
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$,
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_uid::text, 0));$y$);

select pg_temp.olcek_yama(
  'public.join_matchmaking(text)',
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$,
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_player_id::text, 0));$y$);

-- Eşleşmede rakibin üyelik kilidi BEKLEMEDEN denenir (iki çağrı birbirini
-- beklerse kilitlenirdi) ve rakibin canlı odası kilit altında yeniden
-- denetlenir. Alınamazsa ya da rakip bu arada odaya girdiyse bu çağrı bekleme
-- kuyruğuna geçer; rakip bir sonraki yoklamada bizi bulur.
select pg_temp.olcek_yama(
  'public.join_matchmaking(text)',
  E'  if v_opponent is null then\n    insert into public.matchmaking_queue (',
  E'  if v_opponent is not null then\n'
  '    if not pg_try_advisory_xact_lock(\n'
  '             hashtextextended(''room-membership:'' || v_opponent::text, 0))\n'
  '       or exists (\n'
  '         select 1\n'
  '         from public.room_players opp_player\n'
  '         join public.rooms opp_room on opp_room.id = opp_player.room_id\n'
  '         where opp_player.player_id = v_opponent\n'
  '           and opp_player.left_at is null\n'
  '           and opp_room.status in (''lobby'', ''active'')\n'
  '       ) then\n'
  '      v_opponent := null;\n'
  '    end if;\n'
  '  end if;\n\n'
  '  if v_opponent is null then\n    insert into public.matchmaking_queue (');

-- cleanup_stale_rooms üyelik kabul etmez; bayat odaları `for update skip
-- locked` satır kilidiyle kapatır. Global kilit her dakikalık temizlikte bütün
-- oda kurma/katılma çağrılarını durduruyordu.
select pg_temp.olcek_yama(
  'public.cleanup_stale_rooms()',
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$,
  $y$-- (2026-11-04) Global üyelik kilidi kaldırıldı: bu işlev üyelik kabul etmez,
  -- odaları `for update skip locked` satır kilidiyle kapatır.
  perform 1;$y$);

select pg_temp.olcek_yama(
  'public.delete_my_account()',
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$,
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_user_id::text, 0));$y$);

-- Rövanş: kullanıcı kilidi kaynak odayı for update ile kilitlemeden ÖNCE
-- (delete_my_account ile aynı sıra). Eski global kilit satırı yorumla değişir.
select pg_temp.olcek_yama(
  'public.create_room_rematch(uuid)',
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$,
  $y$-- (2026-11-04) Üyelik kilidi artık işlevin başında (kilit sırası).
  perform 1;$y$);
select pg_temp.olcek_yama(
  'public.create_room_rematch(uuid)',
  E'  select * into v_room\n  from public.rooms\n  where id = p_room_id\n  for update;',
  E'  perform pg_advisory_xact_lock(hashtextextended(''room-membership:'' || v_uid::text, 0));\n\n'
  '  select * into v_room\n  from public.rooms\n  where id = p_room_id\n  for update;');

-- Kaçan işlev kalırsa göç durur (sessizce global kilit bırakmak yok).
do $olcek_kilit_kontrol$
declare
  v_kalan text;
begin
  select string_agg(p.oid::regprocedure::text, ', ') into v_kalan
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosrc like '%hashtextextended(''room-membership'', 0)%';
  if v_kalan is not null then
    raise exception 'olcek: global room-membership kilidi kalan işlevler: %', v_kalan;
  end if;
end;
$olcek_kilit_kontrol$;

-- ---------------------------------------------------------------------------
-- 3c. Arkadaş ekleme saatlik sınır; davet ve soru önerisi yarışa karşı güvenli
-- ---------------------------------------------------------------------------
-- Her çağrı sayılır (yoklama/engel denemeleri dahil). Kova kilidi işlem
-- boyunca tutulduğundan işlevdeki 24 saatlik 30 istek sayımı da yarışa kapanır.
select pg_temp.olcek_yama(
  'public.add_friend(uuid,text)',
  '  -- Engelleme (2026-10-02 M5): iki yönden biri engelliyse istek gitmez.',
  E'  -- Saatte en çok 50 çağrı (2026-11-04 ölçek sertleştirme).\n'
  '  if not public.rate_limit_hit(''add_friend'', 50, interval ''1 hour'') then\n'
  '    return query select false, ''Too many friend requests''::text;\n'
  '    return;\n'
  '  end if;\n\n'
  '  -- Engelleme (2026-10-02 M5): iki yönden biri engelliyse istek gitmez.');

-- Saatlik davet sayımı ile ekleme arasındaki yarış: aynı kullanıcının iki
-- eşzamanlı çağrısı ikisi de eski sayıyı görüp sınırı aşabiliyordu.
select pg_temp.olcek_yama(
  'public.invite_friends_to_room(uuid,uuid[])',
  '  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).',
  E'  perform pg_advisory_xact_lock(hashtextextended(''invite:'' || v_uid::text, 0));\n\n'
  '  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).');

create or replace function public.limit_suggested_question_rate()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_recent integer;
begin
  if auth.uid() is null then
    return new;
  end if;

  -- Sayım+ekleme yarışı: aynı kullanıcının eşzamanlı eklemeleri ikisi de 9'u
  -- görüp 11. öneriyi yazabiliyordu.
  perform pg_advisory_xact_lock(
    hashtextextended('suggest:' || new.user_id::text, 0));

  select count(*)::integer into v_recent
  from (
    select 1
    from public.suggested_questions s
    where s.user_id = new.user_id
      and s.created_at > now() - interval '24 hours'
    limit 10
  ) recent;

  if v_recent >= 10 then
    raise exception 'suggestion_rate_limited' using errcode = 'ZK429';
  end if;
  return new;
end;
$function$;
revoke all on function public.limit_suggested_question_rate()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. room_messages RLS maliyeti
-- ---------------------------------------------------------------------------
drop policy if exists room_messages_member_select on public.room_messages;
create policy room_messages_member_select
on public.room_messages
for select
to authenticated
using (
  (
    exists (
      select 1
      from public.room_players rp
      where rp.room_id = room_messages.room_id
        and rp.player_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.rooms r
      where r.id = room_messages.room_id
        and r.host_id = (select auth.uid())
    )
  )
  and not exists (
    select 1
    from public.blocked_users b
    where b.blocker_id = (select auth.uid())
      and b.blocked_id = room_messages.sender_id
  )
);

-- Mesaj geçmişi (room_id, created_at) için. Üyelik aramaları (room_id,
-- player_id) room_players birincil anahtarıyla, (player_id, room_id)
-- room_players_player_room_idx ile zaten karşılanır; yeni indeks gerekmez.
create index if not exists idx_room_messages_room_created
  on public.room_messages (room_id, created_at);

-- ---------------------------------------------------------------------------
-- 1. Sıralama toplamı
-- ---------------------------------------------------------------------------
create table if not exists public.player_score_daily (
  player_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  score bigint not null default 0,
  streak bigint not null default 0,
  rooms bigint not null default 0,
  primary key (player_id, day)
);
create index if not exists player_score_daily_day_idx
  on public.player_score_daily (day, player_id);
alter table public.player_score_daily enable row level security;
revoke all on public.player_score_daily from public, anon, authenticated;

-- Gün kovası: İstanbul günü; finished_at boşsa '-infinity' (yalnız tüm zamanlar).
create or replace function public.score_day_of(p_finished_at timestamptz)
returns date
language sql
stable
set search_path to 'public', 'pg_temp'
as $function$
  select case when p_finished_at is null then '-infinity'::date
              else (p_finished_at at time zone 'Europe/Istanbul')::date end;
$function$;
revoke all on function public.score_day_of(timestamptz)
  from public, anon, authenticated;

-- Tek (oyuncu, gün) çiftini ham satırdan yeniden hesaplar (idempotent; aynı
-- çift için eşzamanlı çağrılar advisory kilitle sıralanır). Filtre eski
-- sıralamayla birebir: bitmiş, ended_reason 'completed' (boş = completed),
-- İstanbul günü. p_day = '-infinity': finished_at boş odalar.
create or replace function public.recompute_player_score_day(p_player_id uuid, p_day date)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_score bigint;
  v_streak bigint;
  v_rooms bigint;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('score-daily:' || p_player_id::text || ':' || p_day::text, 0));

  select
    coalesce(sum(rp.score), 0)::bigint,
    coalesce(max(rp.streak), 0)::bigint,
    count(distinct rp.room_id)::bigint
  into v_score, v_streak, v_rooms
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where rp.player_id = p_player_id
    and r.status = 'finished'
    and coalesce(r.ended_reason, 'completed') = 'completed'
    and (
      (p_day = '-infinity'::date and r.finished_at is null)
      or (p_day <> '-infinity'::date
          and r.finished_at >= (p_day::timestamp at time zone 'Europe/Istanbul')
          and r.finished_at < ((p_day + 1)::timestamp at time zone 'Europe/Istanbul'))
    );

  if v_rooms = 0 then
    delete from public.player_score_daily d
    where d.player_id = p_player_id and d.day = p_day;
  else
    insert into public.player_score_daily as d (player_id, day, score, streak, rooms)
    values (p_player_id, p_day, v_score, v_streak, v_rooms)
    on conflict (player_id, day) do update
      set score = excluded.score,
          streak = excluded.streak,
          rooms = excluded.rooms;
  end if;
end;
$function$;
revoke all on function public.recompute_player_score_day(uuid, date)
  from public, anon, authenticated;

-- Oda bitince / bitmiş odanın durumu, nedeni ya da zamanı değişince oyuncuların
-- ilgili günleri yeniden hesaplanır. Puanlar oda bitmeden ÖNCE yazılır (cevap
-- ve ayrılma yolları). Toplam hatası oyun bitişini ASLA bozmaz: uyarı verilir,
-- `rebuild_player_score_daily` ile onarılır.
create or replace function public.on_room_score_daily()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_old_day date;
  v_new_day date;
  v_player uuid;
begin
  if old.status = 'finished'
     and coalesce(old.ended_reason, 'completed') = 'completed' then
    v_old_day := public.score_day_of(old.finished_at);
  end if;
  if new.status = 'finished'
     and coalesce(new.ended_reason, 'completed') = 'completed' then
    v_new_day := public.score_day_of(new.finished_at);
  end if;
  if v_old_day is null and v_new_day is null then
    return null;
  end if;

  for v_player in
    select rp.player_id from public.room_players rp where rp.room_id = new.id
  loop
    if v_old_day is not null then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;
    if v_new_day is not null and v_new_day is distinct from v_old_day then
      perform public.recompute_player_score_day(v_player, v_new_day);
    end if;
  end loop;
  return null;
exception when others then
  raise warning 'player_score_daily güncellenemedi (oda %): %', new.id, sqlerrm;
  return null;
end;
$function$;
revoke all on function public.on_room_score_daily()
  from public, anon, authenticated;

-- Onarım/yeniden kurma: p_since boşsa tüm tablo, doluysa o günden sonrası ham
-- satırdan yeniden yazılır (onarım aracı; yalnız service_role/bakım; göçte
-- KULLANILMAZ çünkü tabloyu siler).
create or replace function public.rebuild_player_score_daily(p_since date default null)
returns bigint
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_rows bigint;
begin
  delete from public.player_score_daily d
  where p_since is null or d.day >= p_since;

  insert into public.player_score_daily (player_id, day, score, streak, rooms)
  select
    rp.player_id,
    public.score_day_of(r.finished_at),
    coalesce(sum(rp.score), 0)::bigint,
    coalesce(max(rp.streak), 0)::bigint,
    count(distinct rp.room_id)::bigint
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where r.status = 'finished'
    and coalesce(r.ended_reason, 'completed') = 'completed'
    and (p_since is null or public.score_day_of(r.finished_at) >= p_since)
  group by rp.player_id, public.score_day_of(r.finished_at);

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$function$;
revoke all on function public.rebuild_player_score_daily(date)
  from public, anon, authenticated;
grant execute on function public.rebuild_player_score_daily(date) to service_role;

-- GERİ DOLDURMA (üstteki tutarlılık şeması): 1) başlangıç zamanı, 2) kilitsiz
-- toplu ekleme (var olan satıra dokunmaz), 3) tetikleyici (kısa tablo kilidi),
-- 4) kilit altında yakalama.
create temp table olcek_baslangic on commit drop as
  select clock_timestamp() as t;

insert into public.player_score_daily (player_id, day, score, streak, rooms)
select
  rp.player_id,
  public.score_day_of(r.finished_at),
  coalesce(sum(rp.score), 0)::bigint,
  coalesce(max(rp.streak), 0)::bigint,
  count(distinct rp.room_id)::bigint
from public.room_players rp
join public.rooms r on r.id = rp.room_id
where r.status = 'finished'
  and coalesce(r.ended_reason, 'completed') = 'completed'
group by rp.player_id, public.score_day_of(r.finished_at)
on conflict (player_id, day) do nothing;

drop trigger if exists trg_rooms_score_daily on public.rooms;
create trigger trg_rooms_score_daily
after update of status, ended_reason, finished_at on public.rooms
for each row
when (
  (old.status = 'finished' or new.status = 'finished')
  and (old.status, old.ended_reason, old.finished_at)
      is distinct from (new.status, new.ended_reason, new.finished_at)
)
execute function public.on_room_score_daily();

-- Yakalama: tetikleyici artık kurulu ve rooms kilitli; geri doldurma
-- başlangıcından (5 dk pay) bu yana bitmiş ya da finished_at boş odaların
-- (oyuncu, gün) çiftleri ham satırdan yeniden hesaplanır.
select public.recompute_player_score_day(x.player_id, x.day)
from (
  select distinct rp.player_id, public.score_day_of(r.finished_at) as day
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.status = 'finished'
    and coalesce(r.ended_reason, 'completed') = 'completed'
    and (r.finished_at is null
         or r.finished_at >= (select t from olcek_baslangic) - interval '5 minutes')
) x;

-- Günlük satırları (pencereye göre) döndüren iç yardımcı. Tam günler toplam
-- tablosundan, pencerenin başladığı KISMİ gün ham satırdan okunur; sonuç eski
-- `finished_at >= now() - N gün` süzgeciyle aynıdır. p_days <= 0: tüm zamanlar.
-- Engelleme süzgeci çağıranlardadır (oyuncu başına olduğundan eşdeğerdir).
create or replace function public.leaderboard_daily_rows(
  p_days integer,
  p_player_ids uuid[] default null
)
returns table(player_id uuid, day_score bigint, day_streak bigint, day_rooms bigint)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  with cut as (
    select
      case when p_days <= 0 then null
           else now() - make_interval(days => p_days) end as ts
  ),
  edge as (
    select ts, (ts at time zone 'Europe/Istanbul')::date as d from cut
  )
  select a.player_id, a.score, a.streak, a.rooms
  from public.player_score_daily a, edge e
  where (e.ts is null or a.day > e.d)
    and (p_player_ids is null or a.player_id = any(p_player_ids))
  union all
  select
    rp.player_id,
    coalesce(sum(rp.score), 0)::bigint,
    coalesce(max(rp.streak), 0)::bigint,
    count(distinct rp.room_id)::bigint
  from edge e
  join public.rooms r
    on e.ts is not null
   and r.status = 'finished'
   and r.finished_at >= e.ts
   and (r.finished_at at time zone 'Europe/Istanbul')::date = e.d
  join public.room_players rp on rp.room_id = r.id
  where coalesce(r.ended_reason, 'completed') = 'completed'
    and (p_player_ids is null or rp.player_id = any(p_player_ids))
  group by rp.player_id;
$function$;
revoke all on function public.leaderboard_daily_rows(integer, uuid[])
  from public, anon, authenticated;

create or replace function public.get_leaderboard(p_days integer default -1, p_limit integer default 10)
returns table(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select dr.player_id, dr.day_score, dr.day_streak, dr.day_rooms
    from public.leaderboard_daily_rows(p_days) dr
    where not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = auth.uid()
        and b.blocked_id = dr.player_id
    )
  )
  select
    pd.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(pd.day_score), 0)::bigint,
    coalesce(max(pd.day_streak), 0)::bigint,
    coalesce(sum(pd.day_rooms), 0)::bigint,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from per_day pd
  left join public.profiles p on p.id = pd.player_id
  group by
    pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(pd.day_score), 0) > 0
  order by coalesce(sum(pd.day_score), 0) desc,
    coalesce(max(pd.day_streak), 0) desc,
    coalesce(sum(pd.day_rooms), 0) desc,
    pd.player_id asc
  limit least(greatest(p_limit, 1), 100);
$function$;

create or replace function public.get_my_leaderboard_rank(p_days integer default -1)
returns table(rank bigint, player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select dr.player_id, dr.day_score, dr.day_streak, dr.day_rooms
    from public.leaderboard_daily_rows(p_days) dr
    where not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = auth.uid()
        and b.blocked_id = dr.player_id
    )
  ),
  board as (
    select
      pd.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(pd.day_score), 0)::bigint as total_score,
      coalesce(max(pd.day_streak), 0)::bigint as best_streak,
      coalesce(sum(pd.day_rooms), 0)::bigint as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from per_day pd
    left join public.profiles p on p.id = pd.player_id
    group by
      pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(pd.day_score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc,
          b.player_id asc
      ) as row_no
    from board b
  )
  select
    o.row_no as rank,
    o.player_id,
    o.display_name,
    o.total_score,
    o.best_streak,
    o.rooms_played,
    o.avatar_icon,
    o.avatar_color,
    o.avatar_url,
    o.avatar_frame,
    o.showcase_title
  from ordered o
  where o.player_id = auth.uid()
  limit 1;
$function$;

create or replace function public.get_friends_leaderboard(p_days integer default -1)
returns table(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, experience bigint, is_self boolean)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with visible_players as (
    select f.friend_id as player_id
    from public.friends f
    where f.user_id = auth.uid()
      and not exists (
        select 1
        from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = f.friend_id
      )
    union
    select auth.uid()
    where auth.uid() is not null
  ),
  per_day as (
    select dr.player_id, dr.day_score, dr.day_streak, dr.day_rooms
    from public.leaderboard_daily_rows(
      p_days,
      (select coalesce(array_agg(vp.player_id), '{}'::uuid[]) from visible_players vp)
    ) dr
  )
  select
    vp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(pd.day_score), 0)::bigint,
    coalesce(max(pd.day_streak), 0)::bigint,
    coalesce(sum(pd.day_rooms), 0)::bigint,
    coalesce(p.xp, 0)::bigint,
    vp.player_id = auth.uid()
  from visible_players vp
  left join per_day pd on pd.player_id = vp.player_id
  left join public.profiles p on p.id = vp.player_id
  group by vp.player_id, p.display_name, p.xp
  order by
    coalesce(sum(pd.day_score), 0) desc,
    coalesce(max(pd.day_streak), 0) desc,
    coalesce(sum(pd.day_rooms), 0) desc,
    vp.player_id asc;
$function$;

revoke all on function public.get_leaderboard(integer, integer) from public, anon;
grant execute on function public.get_leaderboard(integer, integer) to authenticated;
revoke all on function public.get_my_leaderboard_rank(integer) from public, anon;
grant execute on function public.get_my_leaderboard_rank(integer) to authenticated;
revoke all on function public.get_friends_leaderboard(integer) from public, anon;
grant execute on function public.get_friends_leaderboard(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Push V2: uyandırma sönümlemesi
-- ---------------------------------------------------------------------------
alter table public.push_delivery_v2_config
  add column if not exists last_wake_at timestamptz;

create or replace function public.wake_push_delivery_v2()
returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $wake$
declare
  v_url text;
  v_secret text;
  v_now timestamptz := clock_timestamp();
begin
  if not exists (select 1 from public.push_delivery_v2_config c where c.singleton and c.enabled)
     or not exists (select 1 from public.push_outbox o
       where o.delivery_status in ('pending', 'retry', 'leased')
         and (o.claimed_at is null or o.claim_token is not null)
         and o.next_attempt_at <= v_now
         and (o.lease_until is null or o.lease_until <= v_now)) then return false; end if;
  select s.decrypted_secret into v_url from vault.decrypted_secrets s
    where s.name = 'send_push_url' limit 1;
  select s.decrypted_secret into v_secret from vault.decrypted_secrets s
    where s.name = 'cron_secret' limit 1;
  if nullif(btrim(v_url), '') is null or nullif(btrim(v_secret), '') is null then return false; end if;
  -- Sönümleme (2026-11-04): son uyandırmadan bu yana 2 sn geçmediyse HTTP
  -- isteği atılmaz; çalışan Edge işlevi kuyruğu boşalana dek döngüde kalır,
  -- kaçan iş en geç dakikalık kurtarma cron'unda alınır. Koşullu güncelleme
  -- atomik: eşzamanlı eklemelerden yalnız biri aralığı kazanır.
  update public.push_delivery_v2_config c
     set last_wake_at = v_now
   where c.singleton
     and (c.last_wake_at is null or c.last_wake_at <= v_now - interval '2 seconds');
  if not found then return false; end if;
  perform net.http_post(url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', v_secret),
    body := '{}'::jsonb, timeout_milliseconds := 20000);
  return true;
exception when others then
  -- Push teslimat altyapısı arkadaşlık/oda işlemini geri alamaz. Cron dener.
  return false;
end;
$wake$;
revoke all on function public.wake_push_delivery_v2() from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Doğrulama
-- ---------------------------------------------------------------------------
do $olcek_dogrulama$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.rate_limit_hit(text,integer,interval)',
    'public.recompute_player_score_day(uuid,date)',
    'public.on_room_score_daily()',
    'public.rebuild_player_score_daily(date)',
    'public.leaderboard_daily_rows(integer,uuid[])',
    'public.wake_push_delivery_v2()'
  ] loop
    if has_function_privilege('anon', v_fn, 'execute')
       or has_function_privilege('authenticated', v_fn, 'execute') then
      raise exception 'olcek: % istemciye açık olmamalı', v_fn;
    end if;
  end loop;
  foreach v_fn in array array[
    'public.get_leaderboard(integer,integer)',
    'public.get_my_leaderboard_rank(integer)',
    'public.get_friends_leaderboard(integer)'
  ] loop
    if has_function_privilege('anon', v_fn, 'execute')
       or not has_function_privilege('authenticated', v_fn, 'execute') then
      raise exception 'olcek: % yetkisi yanlış', v_fn;
    end if;
  end loop;
  if not exists (
    select 1 from pg_trigger t
    where t.tgrelid = 'public.rooms'::regclass
      and t.tgname = 'trg_rooms_score_daily' and not t.tgisinternal
  ) then
    raise exception 'olcek: trg_rooms_score_daily kurulmadı';
  end if;
end;
$olcek_dogrulama$;

commit;
