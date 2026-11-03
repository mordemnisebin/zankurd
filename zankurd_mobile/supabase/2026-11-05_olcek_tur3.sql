-- Ölçek denetimi 2. tur (Copilot + Gemini Flash; her bulgu kodda doğrulandı).
-- CANLIYA UYGULANMADI. Geri alma: geri_al/2026-11-05_olcek_tur3_geri.sql
-- Büyük tablo indeksleri: 2026-11-05_olcek_tur3_indeks_concurrently.sql
-- (transaction DIŞINDA; bu göçten önce ya da sonra koşulabilir).
--
-- Taban (canlı ✅): join_matchmaking = 2026-10-18_oda_kod_kategori.sql gövdesi
-- + 2026-11-04_olcek_sertlestirme.sql yamaları; cleanup_stale_rooms =
-- 2026-10-24_sunucu_sertlestirme.sql + aynı yama; get_my_leaderboard_rank =
-- 2026-11-04_olcek_sertlestirme.sql; touch_presence/get_presence_visibility =
-- 2026-10-30_presence.sql. İlk ikisi canlı gövde okunup bağlayıcı metin TAM BİR
-- kez bulunursa yamalanır (idempotent; canlı gövde değişmişse göç durur).
--
-- 1. join_matchmaking: 'matchmaking:<kategori>' kilidi her çağrıda bekleyerek
--    alınıyordu; "Rastgele" tek sanal kuyruk olduğundan bütün arayanlar
--    sıraya giriyordu. Artık İKİ GEÇİŞ: 1) kilitsiz ara (for update skip locked,
--    olcek_sertlestirme'deki rakip kullanıcı kilidi aynen); rakip varsa
--    eşleş (kuyruk doluyken yük altındaki yaygın yol). 2) Yoksa kilidi al ve
--    BİR KEZ daha ara, sonra bekleme satırı ekle. İstemci bekleme sırasında
--    join'i yeniden çağırmaz (yalnız touch_matchmaking), bu yüzden "ikisi de
--    görmeden ikisi de bekler" yarışı kilit altında ikinci aramayla kapanmak
--    ZORUNDA: ilk kilidi alan satırını işleyip commit eder, ikincisi kilidi
--    alınca o satırı görür. Çift eşleşme yok: aday satır `for update skip
--    locked` ile kilitlenir, eşleşen satırın room_id'si dolar. Bayat satır
--    temizliği artık başka işlemin kilitli satırını BEKLEMEZ (skip locked):
--    kilit bekleyen bir çağrının kendi silinmiş satırı yüzünden kilitlenme yok.
--    KİLİT SIRASI (kilitlenme güvenliği; bir işlem ASLA başka birinin tutacağı
--    bir kilidi, kendi tuttuğu satır kilidiyle BEKLEMEZ):
--      kullanıcı kilidi -> (kendi/rakip satır kilitleri, hepsi skip locked ya
--      da bekleme yok) -> matchmaking:<kategori> (yalnız ikinci geçiş).
--    Kategori kilidini tutan işlem başkasının satır kilidini hiç beklemez
--    (arama, bayat silme, rakip güncelleme: skip locked / kendi kilitli satırı).
--    Bu yüzden satır kilidi tutarken kategori kilidini beklemek güvenlidir,
--    AMA touch_matchmaking önceden kategori kilidini alıp sonra satırı
--    güncelliyordu (tersi) -> kilitlenme. touch artık kategori kilidi almaz;
--    kalp atışının satırı o anda kilitlemesi yüzünden aramanın o satırı
--    kaçırması, aramanın "kilitli aday var mı" bakıp 30 ms'lik kısa yeniden
--    denemeyle (en çok 5) kapatılır (pg_sleep; kilit beklemesi değil).
-- 2. touch_presence_v2(): dokunuş + görünürlüğü tek RPC'de döndürür.
-- 3. cleanup_stale_rooms: korelasyonlu max() alt sorguları yalnız ucuz bir
--    "yaş" süzgecini geçen odalara iner (oluşturulma/başlama zamanı eşiğin
--    gerisindeyse tablolara bakılmaz; greatest() bunları zaten içerir, sonuç
--    aynı). Eksik indeks iddiası KISMEN yanlış: player_answers
--    (room_id, question_id, player_id) ve room_invites (room_id, invitee_id)
--    tekil kısıtları room_id önekiyle zaten indeksli, room_messages
--    (room_id, created_at) 11-04'te var; gerçek eksik rooms'ta lobby/active
--    kısmi indeksi (CONCURRENTLY dosyasında).
-- 4. push_outbox / rate_limit_events saklama: pg_cron günlük, toplu silme.
-- 5. get_my_leaderboard_rank: row_number() penceresi + profil birleşimi yerine
--    1 + daha önde olan oyuncu sayısı; sıralama anahtarı eskisiyle aynı
--    (toplam puan, en iyi seri, oyun sayısı azalan; player_id artan).
-- 6. player_score_daily gecelik mutabakat (tetikleyici hatayı WARNING ile
--    yutuyordu): son 2 gün ham satırdan karşılaştırılır, sapan çiftler
--    (oyuncu, gün) SIRALI yeniden hesaplanır (tetikleyiciyle aynı kilit
--    sırası: oyuncu, sonra gün), sapma/kalan sayısı score_reconcile_log'a
--    yazılır. Düzeltilemeyen çiftler score_reconcile_failures'a alınıp
--    sonraki turda sona atılır (kalıcı hata başkalarını aç bırakmaz).
begin;

set local lock_timeout = '10s';

do $tur3_onkosul$
begin
  if to_regprocedure('public.join_matchmaking(text)') is null
     or to_regprocedure('public.cleanup_stale_rooms()') is null
     or to_regprocedure('public.get_my_leaderboard_rank(integer)') is null
     or to_regprocedure('public.leaderboard_daily_rows(integer,uuid[])') is null
     or to_regprocedure('public.recompute_player_score_day(uuid,date)') is null
     or to_regprocedure('public.score_day_of(timestamptz)') is null
     or to_regclass('public.player_score_daily') is null
     or to_regclass('public.rate_limit_events') is null
     or to_regclass('public.push_outbox') is null
     or to_regclass('public.user_presence') is null
     or to_regclass('public.matchmaking_queue') is null then
    raise exception 'tur3: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
end;
$tur3_onkosul$;

create or replace function pg_temp.tur3_yama(p_imza text, p_eski text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_def text;
  v_adet integer;
begin
  v_def := pg_get_functiondef(to_regprocedure(p_imza));
  if v_def is null then
    raise exception 'tur3: işlev yok: %', p_imza;
  end if;
  if position(p_yeni in v_def) > 0 then
    return;
  end if;
  v_adet := (length(v_def) - length(replace(v_def, p_eski, ''))) / length(p_eski);
  if v_adet <> 1 then
    raise exception 'tur3: % için bağlayıcı metin % kez bulundu (1 beklenir); canlı gövde değişmiş, yeniden incele', p_imza, v_adet;
  end if;
  execute replace(v_def, p_eski, p_yeni);
end;
$yama$;

-- İki bağlayıcıyı TEK create or replace'te değiştirir (ara hâl geçerli olmak
-- zorunda: loop açma ve kapama ayrı ayrı yamalanamaz).
create or replace function pg_temp.tur3_yama2(
  p_imza text, p_eski1 text, p_yeni1 text, p_eski2 text, p_yeni2 text)
returns void language plpgsql as $yama2$
declare
  v_def text;
begin
  v_def := pg_get_functiondef(to_regprocedure(p_imza));
  if v_def is null then
    raise exception 'tur3: işlev yok: %', p_imza;
  end if;
  if position(p_yeni1 in v_def) > 0 and position(p_yeni2 in v_def) > 0 then
    return;
  end if;
  if (length(v_def) - length(replace(v_def, p_eski1, ''))) / length(p_eski1) <> 1
     or (length(v_def) - length(replace(v_def, p_eski2, ''))) / length(p_eski2) <> 1 then
    raise exception 'tur3: % için bağlayıcı metin 1 kez bulunamadı; canlı gövde değişmiş, yeniden incele', p_imza;
  end if;
  execute replace(replace(v_def, p_eski1, p_yeni1), p_eski2, p_yeni2);
end;
$yama2$;

-- ---------------------------------------------------------------------------
-- 1. join_matchmaking: kilitsiz ilk geçiş, kilitli ikinci geçiş
-- ---------------------------------------------------------------------------
select pg_temp.tur3_yama(
  'public.join_matchmaking(text)',
  $e$  v_attempt integer;
begin
  if v_player_id is null then$e$,
  $y$  v_attempt integer;
  v_pass integer;
begin
  if v_player_id is null then$y$);

-- Kategori kilidi buradan kalkar; ikinci geçişte (aşağıda) alınır.
select pg_temp.tur3_yama(
  'public.join_matchmaking(text)',
  $e$  perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));$e$,
  $y$  -- (2026-11-05) matchmaking:<kategori> kilidi artık yalnız ikinci geçişte
  -- (rakip bulunamadıysa) alınır; ilk geçiş kilitsizdir.$y$);

-- Bayat satırlar: kilitli satırı bekleme (skip locked).
select pg_temp.tur3_yama(
  'public.join_matchmaking(text)',
  $e$  delete from public.matchmaking_queue mq
  where mq.room_id is null
    and upper(mq.category_name) = upper(v_category_name)
    and not (
        (mq.last_seen_at is null
          and mq.joined_at >= now() - interval '40 seconds')
        or coalesce(mq.last_seen_at > now() - interval '12 seconds', false)
      );$e$,
  $y$  delete from public.matchmaking_queue mq
  where mq.ctid in (
    select s.ctid
    from public.matchmaking_queue s
    where s.room_id is null
      and upper(s.category_name) = upper(v_category_name)
      and not (
          (s.last_seen_at is null
            and s.joined_at >= now() - interval '40 seconds')
          or coalesce(s.last_seen_at > now() - interval '12 seconds', false)
        )
    for update skip locked
  );$y$);

select pg_temp.tur3_yama2(
  'public.join_matchmaking(text)',
  $e$  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)$e$,
  $y$  v_pass := 0;
  loop
  v_pass := v_pass + 1;
  v_opponent := null;
  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)$y$,
  $e$  if v_opponent is null then
    insert into public.matchmaking_queue ($e$,
  $y$  if v_opponent is null and v_pass = 1 then
    -- İkinci geçiş: kategori kilidi (kendi satırından SONRA ama hiçbir satır
    -- kilidi beklemeden; bayat silme skip locked, rakip arama skip locked).
    perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));
    continue;
  end if;
  if v_opponent is null and v_pass < 6 and exists (
    select 1
    from public.matchmaking_queue w
    where upper(w.category_name) = upper(v_category_name)
      and w.player_id <> v_player_id
      and w.room_id is null
      and (
          (w.last_seen_at is null
            and w.joined_at >= now() - interval '40 seconds')
          or coalesce(w.last_seen_at > now() - interval '12 seconds', false)
        )
  ) then
    -- Aday var ama kilitli (kalp atışı/başka eşleşme): kısa bekle, yeniden ara.
    perform pg_sleep(0.03);
    continue;
  end if;
  exit;
  end loop;

  if v_opponent is null then
    insert into public.matchmaking_queue ($y$);

-- touch_matchmaking: kategori kilidi kalktı (kilit sırası; başa bakın).
select pg_temp.tur3_yama(
  'public.touch_matchmaking()',
  $e$  if v_category is not null then
    perform pg_advisory_xact_lock(
      hashtextextended('matchmaking:' || lower(v_category), 0)
    );
  end if;$e$,
  $y$  -- (2026-11-05) Kategori kilidi KALDIRILDI: join ikinci geçişte satır kilidi
  -- tutarken kategori kilidini bekler; burada tersi sıra kilitlenme üretirdi.
  -- Arama kilitli satırı görürse kısa yeniden dener.$y$);

-- ---------------------------------------------------------------------------
-- 2. Varlık: tek RPC (dokunuş + görünürlük)
-- ---------------------------------------------------------------------------
create or replace function public.touch_presence_v2()
returns boolean language plpgsql security definer
set search_path = pg_catalog, public
as $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_visible boolean;
begin
  if v_uid is null then raise insufficient_privilege using message = 'authentication required'; end if;
  -- touch_presence() ile aynı atomik UPDATE; satır güncellendiyse görünürdür.
  update public.user_presence set last_seen_at = v_now, last_touch_at = v_now
  where user_id = v_uid and visible
    and (last_touch_at is null or last_touch_at <= v_now - interval '60 seconds')
  returning true into v_visible;
  if v_visible is null then
    -- 60 sn içinde zaten dokunulmuş (görünür) ya da kapalı/hiç yok.
    select coalesce(p.visible, false) into v_visible
    from public.user_presence p where p.user_id = v_uid;
    v_visible := coalesce(v_visible, false);
  end if;
  return v_visible;
end;
$function$;
revoke all on function public.touch_presence_v2() from public, anon;
grant execute on function public.touch_presence_v2() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. cleanup_stale_rooms: önce ucuz yaş süzgeci
-- ---------------------------------------------------------------------------
-- Lobi: greatest(r.created_at, ...) < 30 dk ise r.created_at < 30 dk zorunlu.
select pg_temp.tur3_yama(
  'public.cleanup_stale_rooms()',
  $e$      r.status = 'lobby'
      and greatest($e$,
  $y$      r.status = 'lobby'
      and r.created_at < now() - interval '30 minutes'
      and greatest($y$);
-- Aktif: greatest(coalesce(started_at, created_at), ...) < 10 dk ise
-- coalesce(started_at, created_at) < 10 dk zorunlu (hazır-süresi kolu ayrı).
select pg_temp.tur3_yama(
  'public.cleanup_stale_rooms()',
  $e$        greatest(
          coalesce(r.started_at, r.created_at),$e$,
  $y$        coalesce(r.started_at, r.created_at) < now() - interval '10 minutes'
        and greatest(
          coalesce(r.started_at, r.created_at),$y$);

-- Küçük, sıcak tablo: bekleyen arama sırası.
create index if not exists matchmaking_queue_waiting_idx
  on public.matchmaking_queue (upper(category_name), joined_at)
  where room_id is null;

-- ---------------------------------------------------------------------------
-- 4. Saklama (retention): push_outbox ve hız sınırı olayları
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema pg_catalog;

-- Terminal durumlar: sent, skipped, failed, legacy (V2 ack/lease yalnız
-- pending/retry/leased satırlara dokunur; terminal satır yeniden okunmaz).
create or replace function public.push_outbox_retention(
  p_days integer default 14,
  p_batch integer default 5000
)
returns bigint language plpgsql security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_total bigint := 0;
  v_n bigint;
  v_i integer := 0;
begin
  loop
    delete from public.push_outbox o
    where o.ctid in (
      select d.ctid from public.push_outbox d
      where d.delivery_status in ('sent', 'skipped', 'failed', 'legacy')
        and d.created_at < now() - make_interval(days => greatest(p_days, 1))
      limit greatest(p_batch, 100)
      for update skip locked
    );
    get diagnostics v_n = row_count;
    v_total := v_total + v_n;
    v_i := v_i + 1;
    exit when v_n = 0 or v_i >= 40;
  end loop;
  return v_total;
end;
$function$;
revoke all on function public.push_outbox_retention(integer, integer)
  from public, anon, authenticated;

-- Hız sınırı pencereleri 1 saat; 1 günden eski olay işe yaramaz. Kullanıcı
-- bir daha o kovaya dokunmazsa satırlar kalıyordu.
create or replace function public.rate_limit_events_sweep(p_batch integer default 5000)
returns bigint language plpgsql security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_total bigint := 0;
  v_n bigint;
  v_i integer := 0;
begin
  loop
    delete from public.rate_limit_events e
    where e.ctid in (
      select d.ctid from public.rate_limit_events d
      where d.created_at < now() - interval '1 day'
      limit greatest(p_batch, 100)
      for update skip locked
    );
    get diagnostics v_n = row_count;
    v_total := v_total + v_n;
    v_i := v_i + 1;
    exit when v_n = 0 or v_i >= 40;
  end loop;
  return v_total;
end;
$function$;
revoke all on function public.rate_limit_events_sweep(integer)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. get_my_leaderboard_rank: tam pencere yerine sayım
-- ---------------------------------------------------------------------------
-- Eski sıra: row_number() over (order by total_score desc, best_streak desc,
-- rooms_played desc, player_id asc) → eşitlik yok. Yeni: 1 + kendinden önde
-- gelen oyuncu sayısı, aynı anahtar; profil birleşimi/sıralama yok. Engelleme
-- süzgeci ve "puanı 0 olan tabloda yok" kuralı korunur.
-- Canlı gövde beklenen tabanla (2026-11-04_olcek_sertlestirme.sql) eşleşmezse
-- göç durur; eşleşirse tam gövde geri alma için yedek tabloya alınır (ilk
-- çalışmada; yeni gövde zaten kuruluysa dokunulmaz).
create table if not exists public.olcek_tur3_yedek (
  ad text primary key,
  tanim text not null,
  alindi timestamptz not null default now()
);
alter table public.olcek_tur3_yedek enable row level security;
revoke all on public.olcek_tur3_yedek from public, anon, authenticated;

do $tur3_rank_taban$
declare
  v_def text := pg_get_functiondef('public.get_my_leaderboard_rank(integer)'::regprocedure);
begin
  if position('o.player_id < m.player_id' in v_def) > 0 then
    return; -- zaten yeni gövde
  end if;
  if position('row_number() over' in v_def) = 0
     or position('public.leaderboard_daily_rows(p_days)' in v_def) = 0
     or position('b.total_score desc' in v_def) = 0
     or position('b.best_streak desc' in v_def) = 0
     or position('b.rooms_played desc' in v_def) = 0
     or position('b.player_id asc' in v_def) = 0
     or position('blocked_users' in v_def) = 0
     or position('where o.player_id = auth.uid()' in v_def) = 0 then
    raise exception 'tur3: get_my_leaderboard_rank canlı gövdesi beklenen tabanla eşleşmiyor; yeniden incele';
  end if;
  insert into public.olcek_tur3_yedek (ad, tanim)
  values ('get_my_leaderboard_rank(integer)', v_def)
  on conflict (ad) do nothing;
end;
$tur3_rank_taban$;

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
      coalesce(sum(pd.day_score), 0)::bigint as total_score,
      coalesce(max(pd.day_streak), 0)::bigint as best_streak,
      coalesce(sum(pd.day_rooms), 0)::bigint as rooms_played
    from per_day pd
    group by pd.player_id
    having coalesce(sum(pd.day_score), 0) > 0
  ),
  mine as (
    select b.* from board b where b.player_id = auth.uid()
  )
  select
    1 + (
      select count(*)
      from board o, mine m
      where o.total_score > m.total_score
         or (o.total_score = m.total_score and o.best_streak > m.best_streak)
         or (o.total_score = m.total_score and o.best_streak = m.best_streak
             and o.rooms_played > m.rooms_played)
         or (o.total_score = m.total_score and o.best_streak = m.best_streak
             and o.rooms_played = m.rooms_played and o.player_id < m.player_id)
    ) as rank,
    m.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    m.total_score,
    m.best_streak,
    m.rooms_played,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from mine m
  left join public.profiles p on p.id = m.player_id
  limit 1;
$function$;
revoke all on function public.get_my_leaderboard_rank(integer) from public, anon;
grant execute on function public.get_my_leaderboard_rank(integer) to authenticated;

-- Tetikleyici: (oyuncu, gün) advisory kilitleri oyuncu artan, sonra gün artan
-- sırada alınır (mutabakatla aynı sıra; ters sıra kilitlenme üretirdi).
select pg_temp.tur3_yama2(
  'public.on_room_score_daily()',
  $e$    select rp.player_id from public.room_players rp where rp.room_id = new.id
  loop$e$,
  $y$    select rp.player_id from public.room_players rp where rp.room_id = new.id
    order by rp.player_id
  loop$y$,
  $e$    if v_old_day is not null then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;
    if v_new_day is not null and v_new_day is distinct from v_old_day then
      perform public.recompute_player_score_day(v_player, v_new_day);
    end if;$e$,
  $y$    if v_old_day is not null and (v_new_day is null or v_old_day <= v_new_day) then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;
    if v_new_day is not null and v_new_day is distinct from v_old_day then
      perform public.recompute_player_score_day(v_player, v_new_day);
    end if;
    if v_old_day is not null and v_new_day is not null and v_old_day > v_new_day then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;$y$);

-- ---------------------------------------------------------------------------
-- 6. player_score_daily gecelik mutabakat
-- ---------------------------------------------------------------------------
create table if not exists public.score_reconcile_log (
  id bigint generated always as identity primary key,
  ran_at timestamptz not null default now(),
  from_day date not null,
  drift_count integer not null,
  failed_count integer not null default 0,
  remaining_count integer not null default 0
);
alter table public.score_reconcile_log enable row level security;
revoke all on public.score_reconcile_log from public, anon, authenticated;

-- Düzeltilemeyen (oyuncu, gün) çiftleri: sonraki turda sona atılır.
create table if not exists public.score_reconcile_failures (
  player_id uuid not null,
  day date not null,
  failed_at timestamptz not null default now(),
  primary key (player_id, day)
);
alter table public.score_reconcile_failures enable row level security;
revoke all on public.score_reconcile_failures from public, anon, authenticated;

-- Son p_days İstanbul gününün beklenen toplamı ham satırdan hesaplanıp tabloyla
-- karşılaştırılır; sapan (oyuncu, gün) çiftleri recompute_player_score_day ile
-- yeniden yazılır (idempotent). SIRA: önce henüz hata vermemiş çiftler, sonra
-- (oyuncu, gün) artan; kilit sırası tetikleyiciyle aynı. Tek çalışmada en çok
-- 2000 çift (tek işlemde advisory kilit sayısı sınırlı); kalan çiftler
-- remaining_count olarak günlüğe yazılır, sonraki gece sürer. Dönen sayı sapan
-- toplam çift sayısıdır.
create or replace function public.reconcile_player_score_daily(p_days integer default 2)
returns integer language plpgsql security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_from date := (now() at time zone 'Europe/Istanbul')::date
                 - (greatest(p_days, 1) - 1);
  v_players uuid[];
  v_days date[];
  v_total integer;
  v_n integer;
  v_i integer;
  v_drift integer := 0;
  v_failed integer := 0;
begin
  select coalesce(array_agg(x.player_id order by x.bad, x.player_id, x.day), '{}'),
         coalesce(array_agg(x.day order by x.bad, x.player_id, x.day), '{}')
  into v_players, v_days
  from (
    with expected as (
      select
        rp.player_id,
        public.score_day_of(r.finished_at) as day,
        coalesce(sum(rp.score), 0)::bigint as score,
        coalesce(max(rp.streak), 0)::bigint as streak,
        count(distinct rp.room_id)::bigint as rooms
      from public.rooms r
      join public.room_players rp on rp.room_id = r.id
      where r.status = 'finished'
        and coalesce(r.ended_reason, 'completed') = 'completed'
        and r.finished_at >= (v_from::timestamp at time zone 'Europe/Istanbul')
      group by rp.player_id, public.score_day_of(r.finished_at)
    ),
    actual as (
      select a.player_id, a.day, a.score, a.streak, a.rooms
      from public.player_score_daily a
      where a.day >= v_from
    ),
    drift as (
      select coalesce(e.player_id, a.player_id) as player_id,
             coalesce(e.day, a.day) as day
      from expected e
      full join actual a on a.player_id = e.player_id and a.day = e.day
      where e.player_id is null
         or a.player_id is null
         or (e.score, e.streak, e.rooms) is distinct from (a.score, a.streak, a.rooms)
    )
    select d.player_id, d.day,
           (f.player_id is not null) as bad
    from drift d
    left join public.score_reconcile_failures f
      on f.player_id = d.player_id and f.day = d.day
  ) x;

  v_total := coalesce(array_length(v_players, 1), 0);
  v_n := least(v_total, 2000);
  -- 2000 çift, bad=false olanlar önde: kalıcı hata başkalarını aç bırakmaz.
  -- Ama işlenen dilim (oyuncu, gün) sırasında DEĞİL bad/oyuncu/gün sırasındadır;
  -- kilit sırası için dilim kendi içinde (oyuncu, gün) artan sıralanır.
  declare
    v_pl uuid[];
    v_dy date[];
  begin
    select coalesce(array_agg(t.p order by t.p, t.d), '{}'),
           coalesce(array_agg(t.d order by t.p, t.d), '{}')
    into v_pl, v_dy
    from (
      select v_players[g] as p, v_days[g] as d
      from generate_series(1, v_n) g
    ) t;
    for v_i in 1 .. v_n loop
      v_drift := v_drift + 1;
      begin
        perform public.recompute_player_score_day(v_pl[v_i], v_dy[v_i]);
        delete from public.score_reconcile_failures f
        where f.player_id = v_pl[v_i] and f.day = v_dy[v_i];
      exception when others then
        v_failed := v_failed + 1;
        insert into public.score_reconcile_failures (player_id, day)
        values (v_pl[v_i], v_dy[v_i])
        on conflict (player_id, day) do update set failed_at = now();
        raise warning 'reconcile_player_score_daily: % % düzeltilemedi: %',
          v_pl[v_i], v_dy[v_i], sqlerrm;
      end;
    end loop;
  end;

  insert into public.score_reconcile_log
    (from_day, drift_count, failed_count, remaining_count)
  values (v_from, v_total, v_failed, v_total - v_n);
  delete from public.score_reconcile_log l where l.ran_at < now() - interval '60 days';
  -- Artık sapma göstermeyen (kendiliğinden düzelmiş) eski hata kayıtları.
  delete from public.score_reconcile_failures f where f.failed_at < now() - interval '30 days';

  if v_total > 0 then
    raise warning 'player_score_daily sapması: % çift (düzeltilemeyen %, kalan %)',
      v_total, v_failed, v_total - v_n;
  end if;
  return v_total;
end;
$function$;
revoke all on function public.reconcile_player_score_daily(integer)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Zamanlama (UTC; idempotent): mutabakat 00:15, push 00:20, hız sınırı 00:25
-- ---------------------------------------------------------------------------
select cron.unschedule('reconcile-player-score-daily')
where exists (select 1 from cron.job where jobname = 'reconcile-player-score-daily');
select cron.schedule('reconcile-player-score-daily', '15 0 * * *',
  $$select public.reconcile_player_score_daily(2)$$);

select cron.unschedule('push-outbox-retention')
where exists (select 1 from cron.job where jobname = 'push-outbox-retention');
select cron.schedule('push-outbox-retention', '20 0 * * *',
  $$select public.push_outbox_retention(14, 5000)$$);

select cron.unschedule('rate-limit-events-sweep')
where exists (select 1 from cron.job where jobname = 'rate-limit-events-sweep');
select cron.schedule('rate-limit-events-sweep', '25 0 * * *',
  $$select public.rate_limit_events_sweep(5000)$$);

commit;
