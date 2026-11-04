-- Ölçek denetimi 6. tur (GPT-6 Pro tam denetimi; her bulgu kodda doğrulandı).
-- CANLIYA UYGULANMADI (applied.md ⏳). Geri alma: geri_al/2026-11-05_olcek_tur6_geri.sql
--
-- Taban (canlı ✅): create_online_room_impl = 2026-10-31_room_limits.sql gövdesi +
-- 2026-11-04_olcek_sertlestirme.sql yamaları; reconcile_player_score_total =
-- 2026-11-05_olcek_tur4.sql; get_tournament_bracket = 2026-10-27_turnuva_sunucu_puani.sql
-- gövdesi + 2026-10-30_turnuva_gonderim.sql eki; resolve_expired_tournament_matches =
-- 2026-07-31_tournament_score_authority.sql (= 2026-08-01 baseline). Gövdeler canlıdan
-- `pg_get_functiondef` ile okunur; TAM gövdenin md5'i bilinen tabana eşitse yamalanır
-- (başka her durumda göç durur); eski gövde ve md5'i olcek_tur3_yedek'e ('tur6:<imza>')
-- alınır. Ayrıca yeni nesneler (tablo, işlev, indeks, cron) yaratılır.
--
-- A. create_online_room_impl: bakiye kontrolü "mevcut canlı odayı dön" dalından ÖNCE
--    çalışıyordu. Ücretli oda kurulduktan sonra giriş ücreti düşer; ağ tekrarı ya da
--    çift dokunuş aynı çağrıyı yeniden gönderince bakiye artık yetmez ve "Insufficient
--    coins" alınırdı, oysa oda kurulmuştu (idempotent tekrar reddediliyordu). Kontrol
--    artık mevcut-oda dalından SONRA ve hız sınırından ÖNCE (yeni oda gerçekten
--    kurulacaksa) yapılır; mevcut oda dönerken para istenmez/düşmez. Kilit sırası aynı
--    (kullanıcı kilidi + profil satır kilidi önce) kalır: çift harcama yarışı kapalı.
-- B. player_score_daily gecelik mutabakatı (reconcile_player_score_daily) yalnız son 2
--    günü ve en çok 2000 çifti ele alır; daha eski ya da sığmayan sapma KALICI olarak
--    kaçabilirdi. Yeni kalıcı imleç (score_reconcile_daily_cursor: gün + oyuncu sırası,
--    ilerleme satırı) her gece tarihi baştan sona dilim dilim gezer; dilim başına en
--    çok p_keys anahtar karşılaştırılır, en çok p_repairs çift (oyuncu, gün artan kilit
--    sırasıyla) yeniden yazılır; imleç sona gelince başa sarar (cycles). Sapma
--    düzeltilemezse score_reconcile_failures'a yazılır, imleç ilerler (takılmaz).
--    Elle tam geri doldurma: reconcile_player_score_daily_full(after_day, after_player)
--    ayrı işlemlerde döngüyle çağrılır (service_role); done=true olunca biter.
--    Gece işi (cron 00:35 UTC) ayrı işlemdir; mevcut 00:15 işi DEĞİŞMEZ.
-- C. reconcile_player_score_total: dönen dilimin günlük kolundaki LIMIT, oyuncu başına
--    BİRÇOK günlük satırı sayıyordu (aynı oyuncu tekrar tekrar), böylece dilim gerçek
--    oyuncu sayısından küçük kalıp bazı oyunculara hiç ulaşılmıyordu. Artık
--    `select distinct player_id ... order by ... limit`: önce tekilleştirilir, sonra LIMIT.
-- D. get_tournament_bracket her çağrıda resolve_expired_tournament_matches +
--    start_due_tournaments çalıştırıyordu; ilki süresi dolmuş maçı olan TÜM (bitmiş
--    dahil) turnuvaları advance_tournament'a veriyor, o da her turnuva satırını
--    `for update` kilitliyordu. Okuma artık KİLİTSİZ: süre dolumu/başlatma pg_cron
--    ('tournament-expiry', her dakika, process_tournament_expiry) işidir; ilerletme
--    yalnız 'running' ve son turu tamamen bitmiş turnuvaları seçer. Kısmi indeks
--    (deadline, açık maçlar) güncellemeyi ucuz tutar.
begin;

set local lock_timeout = '10s';

do $tur6_onkosul$
begin
  if to_regprocedure('public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)') is null
     or to_regprocedure('public.reconcile_player_score_total(integer,integer)') is null
     or to_regprocedure('public.get_tournament_bracket()') is null
     or to_regprocedure('public.resolve_expired_tournament_matches()') is null
     or to_regprocedure('public.start_due_tournaments()') is null
     or to_regprocedure('public.advance_tournament(uuid)') is null
     or to_regprocedure('public.recompute_player_score_day(uuid,date)') is null
     or to_regprocedure('public.score_day_of(timestamptz)') is null
     or to_regclass('public.score_reconcile_log') is null
     or to_regclass('public.score_reconcile_failures') is null
     or to_regclass('public.player_score_daily') is null
     or to_regclass('public.tournament_matches') is null
     or to_regclass('cron.job') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'tur6: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Yedek tablosu istemci rollerine kapalı (rollback bu satırlardaki gövdeyi
  -- çalıştırır; yazılabilir olması keyfi kod çalıştırmak demektir).
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'tur6: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  -- Sahibi ve Supabase service_role dışında hiçbir alıcıya (doğrudan grant dahil)
  -- yetki kalmamalı.
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) then
    raise exception 'tur6: olcek_tur3_yedek sahibi dışında alıcıya açık (relacl)';
  end if;
end;
$tur6_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef). Yamadan önce
-- gövde ya (a) tam bu taban olmalı -> yamalanır, ya (b) tam nihai md5'te ve yedek
-- satırı + md5 zinciri sağlam olmalı -> zaten uygulanmış, atlanır. Başka her durum
-- göçü durdurur. sahip / acl / ayar = yamadan önceki sahip, ACL ve proconfig;
-- yama sonrası değişmediği doğrulanır.
create temp table tur6_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[]
) on commit drop;
do $tur6_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)', '49488efbdeb5c45dbddb07cabf388df7', '5d47d382b01acfe27ca6dcad2a883446'),
    ('public.reconcile_player_score_total(integer,integer)', '9b91056fd54b4f374c329f37546147d0', '7f3bffab94ff1555879e215658935160'),
    ('public.get_tournament_bracket()', '09175ca7e7a56cc49fb8b9434212b2b4', '7273314366117df9a634fff441bb5579'),
    ('public.resolve_expired_tournament_matches()', '64428c2a49e83c5275b2eab82144beac', '6dccbfd2d13eeb321f9d2db0be1b30d1')) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into tur6_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'tur6: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); eski bir tur6 varyantı uygulanmış ya da canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur6:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'tur6: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into tur6_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$tur6_durum$;

-- Yamalayıcı (tur5 ile aynı). Uygulanmış sayılması: yeni parça TAM BİR kez var ve
-- yeni parça çıkarıldığında eski parça kalmamış (eski parça yeninin alt metni
-- olabilir). Yamalanması: eski parça TAM BİR kez var ve yeni parça YOK. Başka her
-- durum göçü durdurur. Her yamadan önce CANLI gövde (ve md5'i) yedeğe yazılır; bir
-- işlevin birden çok yaması aynı yedek satırını paylaşır (ilk yama ORİJİNALİ yazar).
create or replace function pg_temp.tur6_yama(p_imza text, p_eski text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_oid regprocedure := to_regprocedure(p_imza);
  v_def text;
  v_eski_n integer;
  v_yeni_n integer;
  v_kalan_n integer;
  v_yedek text;
begin
  if v_oid is null then
    raise exception 'tur6: işlev yok: %', p_imza;
  end if;
  v_def := pg_get_functiondef(v_oid);
  v_eski_n := (length(v_def) - length(replace(v_def, p_eski, ''))) / length(p_eski);
  v_yeni_n := (length(v_def) - length(replace(v_def, p_yeni, ''))) / length(p_yeni);
  v_kalan_n := (length(replace(v_def, p_yeni, ''))
                - length(replace(replace(v_def, p_yeni, ''), p_eski, ''))) / length(p_eski);
  if v_yeni_n = 1 and v_kalan_n = 0 then
    return; -- zaten uygulanmış
  end if;
  if v_yeni_n <> 0 or v_eski_n <> 1 then
    raise exception 'tur6: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur6:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('tur6:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'tur6:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- B. Kalıcı imleçli günlük mutabakat + elle tam geri doldurma
-- ---------------------------------------------------------------------------
create table if not exists public.score_reconcile_daily_cursor (
  id integer primary key check (id = 1),
  last_day date,            -- sıradaki işlenecek gün (boş = başlangıç)
  last_player uuid,         -- o günde son işlenen oyuncu (boş = günün başı)
  cycles bigint not null default 0,
  last_done_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.score_reconcile_daily_cursor enable row level security;
revoke all on public.score_reconcile_daily_cursor from public, anon, authenticated;

-- Bir dilim: (p_after_day, p_after_player)'dan sonraki anahtarları (gün artan, oyuncu
-- artan) en çok p_keys tane karşılaştırır; sapanların (oyuncu, gün artan) en çok
-- p_repairs tanesini recompute_player_score_day ile yeniden yazar. Dönen
-- next_day/next_player sonraki çağrının p_after_* değeridir; done=true tüm tarih
-- gezildi demektir. Kilit sırası tetikleyiciyle aynı: (oyuncu, gün) artan; tek
-- işlemde en çok p_repairs (<= 2000) advisory kilit. p_after_day boşsa başlangıçtan.
create or replace function public.reconcile_player_score_daily_full(
  p_after_day date default null,
  p_after_player uuid default null,
  p_keys integer default 5000,
  p_repairs integer default 1000)
returns table (
  next_day date, next_player uuid, keys_scanned integer,
  drift_count integer, failed_count integer, done boolean)
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_day date := p_after_day;
  v_player uuid := p_after_player;
  v_budget integer := greatest(least(coalesce(p_keys, 5000), 50000), 1);
  v_rbudget integer := greatest(least(coalesce(p_repairs, 1000), 2000), 1);
  v_scanned integer := 0;
  v_drift integer := 0;
  v_failed integer := 0;
  v_done boolean := false;
  v_pl uuid[] := '{}';
  v_dy date[] := '{}';
  v_pl2 uuid[];
  v_dy2 date[];
  v_fp uuid[];
  v_fb boolean[];
  v_fetched integer;
  v_take integer;
  v_i integer;
  v_inf boolean;
  v_lo timestamptz;
  v_hi timestamptz;
  v_next date;
begin
  if v_day is null then
    select min(q.d) into v_day
    from (
      select min(a.day) as d from public.player_score_daily a
      union all
      select '-infinity'::date
      where exists (select 1 from public.rooms r
                    where r.status = 'finished' and r.finished_at is null)
      union all
      select (min(r.finished_at) at time zone 'Europe/Istanbul')::date from public.rooms r
      where r.status = 'finished' and r.finished_at is not null
    ) q;
    v_player := null;
    if v_day is null then
      return query select null::date, null::uuid, 0, 0, 0, true;
      return;
    end if;
  end if;

  loop
    v_inf := (v_day = '-infinity'::date);
    if not v_inf then
      v_lo := v_day::timestamp at time zone 'Europe/Istanbul';
      v_hi := (v_day + 1)::timestamp at time zone 'Europe/Istanbul';
    end if;

    select coalesce(array_agg(k.player_id order by k.player_id), '{}'),
           coalesce(array_agg(k.bad order by k.player_id), '{}')
    into v_fp, v_fb
    from (
      select z.player_id, z.bad
      from (
        select coalesce(e.player_id, a.player_id) as player_id,
               (e.player_id is null or a.player_id is null
                or (e.score, e.streak, e.rooms)
                   is distinct from (a.score, a.streak, a.rooms)) as bad
        from (
          select rp.player_id,
                 coalesce(sum(rp.score), 0)::bigint as score,
                 coalesce(max(rp.streak), 0)::bigint as streak,
                 count(distinct rp.room_id)::bigint as rooms
          from public.rooms r
          join public.room_players rp on rp.room_id = r.id
          where r.status = 'finished'
            and coalesce(r.ended_reason, 'completed') = 'completed'
            and ((v_inf and r.finished_at is null)
                 or (not v_inf and r.finished_at >= v_lo and r.finished_at < v_hi))
          group by rp.player_id
        ) e
        full join (
          select d.player_id, d.score, d.streak, d.rooms
          from public.player_score_daily d
          where d.day = v_day
        ) a on a.player_id = e.player_id
      ) z
      where v_player is null or z.player_id > v_player
      order by z.player_id
      limit v_budget + 1
    ) k;

    v_fetched := coalesce(cardinality(v_fp), 0);
    v_take := 0;
    for v_i in 1 .. least(v_fetched, v_budget) loop
      if v_fb[v_i] then
        exit when cardinality(v_pl) >= v_rbudget;
        v_pl := v_pl || v_fp[v_i];
        v_dy := v_dy || v_day;
      end if;
      v_take := v_take + 1;
    end loop;

    v_scanned := v_scanned + v_take;
    v_budget := v_budget - v_take;
    if v_take > 0 then
      v_player := v_fp[v_take];
    end if;
    -- Gün bitmedi (anahtar ya da onarım bütçesi doldu): imleç burada kalır.
    exit when v_take < v_fetched;

    -- Gün bitti: sonraki gün (kesin büyük) ya da tarih sonu.
    select min(q.d) into v_next
    from (
      select min(a.day) as d from public.player_score_daily a where a.day > v_day
      union all
      select (min(r.finished_at) at time zone 'Europe/Istanbul')::date from public.rooms r
      where r.status = 'finished'
        and r.finished_at >= case when v_inf then '-infinity'::timestamptz else v_hi end
    ) q;
    if v_next is null then
      v_done := true;
      v_day := null;
      v_player := null;
      exit;
    end if;
    v_day := v_next;
    v_player := null;
    exit when v_budget <= 0;
  end loop;

  -- Onarım: kilit sırası (oyuncu, gün) artan.
  if cardinality(v_pl) > 0 then
    select array_agg(t.p order by t.p, t.d), array_agg(t.d order by t.p, t.d)
    into v_pl2, v_dy2
    from (
      select v_pl[g] as p, v_dy[g] as d
      from generate_series(1, cardinality(v_pl)) g
    ) t;
    for v_i in 1 .. cardinality(v_pl2) loop
      v_drift := v_drift + 1;
      begin
        perform public.recompute_player_score_day(v_pl2[v_i], v_dy2[v_i]);
        delete from public.score_reconcile_failures f
        where f.player_id = v_pl2[v_i] and f.day = v_dy2[v_i];
      exception when others then
        v_failed := v_failed + 1;
        insert into public.score_reconcile_failures (player_id, day)
        values (v_pl2[v_i], v_dy2[v_i])
        on conflict (player_id, day) do update set failed_at = now();
        raise warning 'reconcile_player_score_daily_full: % % düzeltilemedi: %',
          v_pl2[v_i], v_dy2[v_i], sqlerrm;
      end;
    end loop;
  end if;

  return query select v_day, v_player, v_scanned, v_drift, v_failed, v_done;
end;
$function$;
revoke all on function public.reconcile_player_score_daily_full(date, uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.reconcile_player_score_daily_full(date, uuid, integer, integer)
  to service_role;

-- Gece işi: kalıcı imleçten bir dilim. Aynı anda ikinci çalışma imleç satırında
-- `skip locked` ile atlanır (0 döner). Hata günü bozmaz: uyarı + -1.
create or replace function public.reconcile_player_score_daily_sweep(
  p_keys integer default 20000, p_repairs integer default 1000)
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_c record;
  r record;
begin
  insert into public.score_reconcile_daily_cursor (id) values (1)
  on conflict (id) do nothing;
  select * into v_c
  from public.score_reconcile_daily_cursor c
  where c.id = 1
  for update skip locked;
  if not found then
    return 0;
  end if;

  select * into r
  from public.reconcile_player_score_daily_full(
    v_c.last_day, v_c.last_player, p_keys, p_repairs);

  update public.score_reconcile_daily_cursor c
  set last_day = r.next_day,
      last_player = r.next_player,
      cycles = c.cycles + case when r.done then 1 else 0 end,
      last_done_at = case when r.done then now() else c.last_done_at end,
      updated_at = now()
  where c.id = 1;

  insert into public.score_reconcile_log
    (from_day, drift_count, failed_count, remaining_count)
  values (coalesce(v_c.last_day, '-infinity'::date),
          r.drift_count, r.failed_count, 0);

  if r.drift_count > 0 then
    raise warning 'player_score_daily tarih taraması: % çift (düzeltilemeyen %), imleç %/%',
      r.drift_count, r.failed_count, r.next_day, r.next_player;
  end if;
  return r.drift_count;
exception when others then
  raise warning 'reconcile_player_score_daily_sweep başarısız: %', sqlerrm;
  return -1;
end;
$function$;
revoke all on function public.reconcile_player_score_daily_sweep(integer, integer)
  from public, anon, authenticated;
grant execute on function public.reconcile_player_score_daily_sweep(integer, integer)
  to service_role;

-- ---------------------------------------------------------------------------
-- D. Turnuva süre dolumu: okuma yolundan cron'a
-- ---------------------------------------------------------------------------
create index if not exists tournament_matches_open_deadline_idx
  on public.tournament_matches (deadline)
  where status <> 'completed' and deadline is not null;

-- Cron girişi: iki iş birbirinden yalıtılır (biri düşerse öteki çalışır).
create or replace function public.process_tournament_expiry()
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  begin
    perform public.resolve_expired_tournament_matches();
  exception when others then
    raise warning 'process_tournament_expiry (süre dolumu): %', sqlerrm;
  end;
  begin
    perform public.start_due_tournaments();
  exception when others then
    raise warning 'process_tournament_expiry (başlatma): %', sqlerrm;
  end;
end;
$function$;
revoke all on function public.process_tournament_expiry()
  from public, anon, authenticated;
grant execute on function public.process_tournament_expiry() to service_role;

-- ---------------------------------------------------------------------------
-- Yamalar
-- ---------------------------------------------------------------------------
-- A1. Bakiye kontrolünü mevcut-oda dalından önceki yerinden kaldır.
select pg_temp.tur6_yama(
  'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  $e$  -- Bakiye kontrolü kilit alındıktan sonra yapılır (çift harcama yarış durumu önlemi)
  if p_entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < p_entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  -- Aktif oda varsa snapshot'ı dön$e$,
  $y$  -- Aktif oda varsa snapshot'ı dön (2026-11-05 tur6: bakiye kontrolü bu dalın
  -- ALTINA taşındı; kurulmuş odanın idempotent tekrarı bakiye sıfırlanmış olsa da
  -- mevcut odayı döner, para istenmez)$y$)
from tur6_durum d
where d.imza = 'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)' and d.gerekli;

-- A2. Bakiye kontrolü: yeni oda gerçekten kurulacaksa (hız sınırından önce; reddedilen
-- deneme sayıma girmez). Kilit sırası değişmedi: kullanıcı kilidi + profil kilidi üstte.
select pg_temp.tur6_yama(
  'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  $e$  -- Saatte en çok 30 yeni oda (2026-11-04 ölçek sertleştirme).$e$,
  $y$  -- Bakiye kontrolü (kilit zaten alındı: çift harcama yarışı kapalı). Yalnız YENİ
  -- oda kurulacaksa; mevcut oda yukarıda parasız döndü (2026-11-05 tur6).
  if p_entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < p_entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  -- Saatte en çok 30 yeni oda (2026-11-04 ölçek sertleştirme).$y$)
from tur6_durum d
where d.imza = 'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)' and d.gerekli;

-- C. Dönen dilim: önce oyuncular tekilleştirilir, SONRA LIMIT.
select pg_temp.tur6_yama(
  'public.reconcile_player_score_total(integer,integer)',
  $e$      (select d.player_id from public.player_score_daily d
       where v_cursor is null or d.player_id > v_cursor
       order by d.player_id limit greatest(p_slice, 1))$e$,
  $y$      (select distinct d.player_id from public.player_score_daily d
       where v_cursor is null or d.player_id > v_cursor
       order by d.player_id limit greatest(p_slice, 1))$y$)
from tur6_durum d
where d.imza = 'public.reconcile_player_score_total(integer,integer)' and d.gerekli;

-- D1. Okuma kilitsiz: süre dolumu/başlatma cron'dadır.
select pg_temp.tur6_yama(
  'public.get_tournament_bracket()',
  $e$  -- Ekran her açıldığında zamanı gelmiş işler yürütülür: süresi dolan
  -- maçlar hükmen kapanır, dolmayı bekleyen turnuvalar eldeki oyuncularla
  -- başlar. Ayrı bir zamanlayıcı gerekmez.
  perform public.resolve_expired_tournament_matches();
  perform public.start_due_tournaments();$e$,
  $y$  -- (2026-11-05 tur6) Okuma KİLİTSİZ ve yan etkisiz: süresi dolan maçların
  -- hükmen kapanması ve dolmayı bekleyen turnuvaların başlatılması pg_cron işidir
  -- ('tournament-expiry', her dakika, process_tournament_expiry). Eskiden her
  -- ekran açılışı bütün turnuvaları kilitleyip tarıyordu.$y$)
from tur6_durum d
where d.imza = 'public.get_tournament_bracket()' and d.gerekli;

-- D2. Süre dolumu ilerletmesi: yalnız 'running' ve SON TURU tamamen bitmiş turnuvalar
-- (advance_tournament'ın gerçekten iş yaptığı küme); bitmiş/geçmiş turnuvalar kilitlenmez.
select pg_temp.tur6_yama(
  'public.resolve_expired_tournament_matches()',
  $e$    select distinct m.tournament_id
      from public.tournament_matches m
     where m.status = 'completed'
       and m.deadline is not null
       and m.deadline < now()
  loop$e$,
  $y$    select t.id
      from public.tournaments t
     where t.status = 'running'
       and exists (
         select 1 from public.tournament_matches m
          where m.tournament_id = t.id)
       and not exists (
         select 1 from public.tournament_matches p
          where p.tournament_id = t.id
            and p.status <> 'completed'
            and p.round = (select max(x.round)
                             from public.tournament_matches x
                            where x.tournament_id = t.id))
     order by t.id
  loop$y$)
from tur6_durum d
where d.imza = 'public.resolve_expired_tournament_matches()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- Zamanlama (UTC; idempotent)
-- ---------------------------------------------------------------------------
select cron.unschedule('reconcile-player-score-daily-sweep')
where exists (select 1 from cron.job where jobname = 'reconcile-player-score-daily-sweep');
select cron.schedule('reconcile-player-score-daily-sweep', '35 0 * * *',
  $$select public.reconcile_player_score_daily_sweep(20000, 1000)$$);

select cron.unschedule('tournament-expiry')
where exists (select 1 from cron.job where jobname = 'tournament-expiry');
select cron.schedule('tournament-expiry', '* * * * *',
  $$select public.process_tournament_expiry()$$);

-- ---------------------------------------------------------------------------
-- Yama sonrası güvenlik doğrulaması: yamalanan işlevlerde SECURITY DEFINER, sahip,
-- ACL ve proconfig DEĞİŞMEDİ, nihai md5 tam, anon/PUBLIC EXECUTE yok; yeni
-- işlevlerde SECURITY DEFINER + sabit search_path + istemci rollerine kapalı.
-- ---------------------------------------------------------------------------
do $tur6_son$
declare
  r record;
  v_imza text;
begin
  for r in select * from tur6_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.prosecdef
        and p.proowner = r.sahip
        and p.proconfig is not null
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'tur6: % SECURITY DEFINER / sahip / search_path / ACL doğrulanamadı', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'tur6: % yama sonrası gövde beklenen nihai md5 değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'tur6: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  foreach v_imza in array array[
    'public.reconcile_player_score_daily_full(date,uuid,integer,integer)',
    'public.reconcile_player_score_daily_sweep(integer,integer)',
    'public.process_tournament_expiry()'] loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(v_imza)
        and p.prosecdef
        and p.proconfig = array['search_path=public, pg_temp']
    ) then
      raise exception 'tur6: % SECURITY DEFINER / tam search_path doğrulanamadı', v_imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(v_imza), 'execute')
       or has_function_privilege('authenticated', to_regprocedure(v_imza), 'execute')
       or has_function_privilege('public', to_regprocedure(v_imza), 'execute') then
      raise exception 'tur6: % istemci rollerine açık', v_imza;
    end if;
  end loop;
  if has_table_privilege('anon', 'public.score_reconcile_daily_cursor', 'select,insert,update,delete')
     or has_table_privilege('authenticated', 'public.score_reconcile_daily_cursor', 'select,insert,update,delete') then
    raise exception 'tur6: score_reconcile_daily_cursor istemci rollerine açık';
  end if;
  if (select count(*) from cron.job
      where jobname in ('reconcile-player-score-daily-sweep', 'tournament-expiry')) <> 2 then
    raise exception 'tur6: cron işleri kurulamadı';
  end if;
end;
$tur6_son$;

commit;
