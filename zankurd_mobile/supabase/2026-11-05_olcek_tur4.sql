-- Ölçek denetimi 3. tur (Copilot + Gemini Flash; her bulgu kodda doğrulandı).
-- Canlıda (2026-11-04/05, applied.md ✅). Geri alma: geri_al/2026-11-05_olcek_tur4_geri.sql
--
-- Taban (canlı ✅): leaderboard_daily_rows / recompute_player_score_day /
-- rebuild_player_score_daily = 2026-11-04_olcek_sertlestirme.sql;
-- reconcile_player_score_daily = 2026-11-05_olcek_tur3.sql;
-- weekly_league_assign = 2026-11-05_haftalik_lig.sql. Yamalanan işlevler canlı
-- gövde `pg_get_functiondef` ile okunup bağlayıcı metin TAM BİR kez bulunursa
-- değiştirilir (idempotent; canlı gövde değişmişse göç durur). Her yamadan önce
-- eski gövde (ve md5'i) olcek_tur3_yedek tablosuna alınır; geri alma oradan.
--
-- 1. Tüm zamanlar sıralaması. get_leaderboard / get_my_leaderboard_rank /
--    get_friends_leaderboard(-1) bütün player_score_daily tablosunu (oyuncu x
--    gün) tarayıp grupluyordu. Artık `leaderboard_daily_rows` p_days <= 0 için
--    bakımı tetikleyici yolunda yapılan `player_score_total` tablosunu (oyuncu
--    başına TEK satır: toplam puan, en iyi seri, oyun sayısı) okur. Üç işlev de
--    bu yardımcıyı kullandığından gövdeleri DEĞİŞMEZ; sonuç aynıdır çünkü
--    çağıranlar zaten oyuncu başına sum/max/sum alıyordu.
--    Bakım: recompute_player_score_day, günlük satırı yazdıktan sonra aynı
--    işlemde oyuncunun toplamını günlük satırlarından yeniden hesaplar
--    (artımlı fark DEĞİL: en iyi seri bir max'tır, silme/değişiklik farkla
--    tutulamaz). Oyuncu başına advisory kilit ('score-total:<oyuncu>') eşzamanlı
--    iki günün birbirinin yazısını ezmesini önler; kilit sırası: önce (oyuncu,
--    gün), sonra oyuncu toplamı; tetikleyici ve mutabakat oyuncuları artan
--    sırada işler, döngü yok. Geri doldurma idempotent (var olan satıra
--    dokunmaz) ve sonunda tam mutabakat. Gecelik mutabakat
--    (reconcile_player_score_daily) artık toplam mutabakatını da çağırır.
-- 2. weekly_league_assign: kademe başına bekleyen advisory kilit haftanın ilk
--    puan alan herkesini sıraya diziyordu. Artık önce `for update skip locked`
--    ile kilitsiz dolmamış küme aranır; yalnız UYGUN KÜME YOKSA (hepsi dolu ya
--    da başka işlemde kilitli) küme-oluşturma kilidi alınır, kilit altında kümeler
--    bu kez BEKLEYEREK yeniden aranır (başkasının doldurduğu küme boş
--    kümeler çoğaltmasın) ve gerekirse yeni küme açılır. Kümeye yazım satır
--    kilidi altında member_count < 30 doğrulamasıyla yapılır: 30 sınırı korunur
--    (tablo CHECK'i de arka kapı). Aynı oyuncunun çift çağrısı oyuncu başına
--    kilitle sıralanır (birincil anahtar hatası yok).
--    Kilit sırası: oyuncu kilidi -> (küme satırı, skip locked) ya da
--    küme-oluşturma kilidi -> küme satırı. Satır kilidini tutan hiç kimse
--    küme-oluşturma kilidini BEKLEMEZ, döngü yok.
begin;

set local lock_timeout = '10s';

do $tur4_onkosul$
begin
  if to_regprocedure('public.leaderboard_daily_rows(integer,uuid[])') is null
     or to_regprocedure('public.recompute_player_score_day(uuid,date)') is null
     or to_regprocedure('public.rebuild_player_score_daily(date)') is null
     or to_regprocedure('public.reconcile_player_score_daily(integer)') is null
     or to_regprocedure('public.weekly_league_assign(uuid,date)') is null
     or to_regclass('public.player_score_daily') is null
     or to_regclass('public.weekly_league_cohorts') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'tur4: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
end;
$tur4_onkosul$;

-- Yamalayıcı. Uygulanmış sayılması: yeni parça TAM BİR kez var ve yeni parça
-- çıkarıldığında eski parça kalmamış (eski parça yeninin alt metni olabilir).
-- Yamalanması: eski parça TAM BİR kez var ve yeni parça YOK. Başka her durum
-- (yarım yama, çift bağlayıcı, değişmiş gövde) göçü durdurur. Her yamadan
-- önce CANLI gövde (ve md5'i) yedeğe yazılır (bayat yedek kalmaz); yamadan
-- sonraki gövdenin md5'i de eklenir, geri alma yalnız o gövdeyi geri çevirir.
create or replace function pg_temp.tur4_yama(p_imza text, p_eski text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_oid regprocedure := to_regprocedure(p_imza);
  v_def text;
  v_eski_n integer;
  v_yeni_n integer;
  v_kalan_n integer;
begin
  if v_oid is null then
    raise exception 'tur4: işlev yok: %', p_imza;
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
    raise exception 'tur4: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  insert into public.olcek_tur3_yedek (ad, tanim, alindi)
  values ('tur4:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
  on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = tanim || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'tur4:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- 1. Tüm zamanlar toplamı
-- ---------------------------------------------------------------------------
create table if not exists public.player_score_total (
  player_id uuid primary key references public.profiles(id) on delete cascade,
  score bigint not null default 0,
  streak bigint not null default 0,
  rooms bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.player_score_total enable row level security;
revoke all on public.player_score_total from public, anon, authenticated;

-- Bir oyuncunun toplamını günlük satırlarından yeniden yazar (idempotent).
create or replace function public.refresh_player_score_total(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_score bigint;
  v_streak bigint;
  v_rooms bigint;
  v_n bigint;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('score-total:' || p_player_id::text, 0));

  select coalesce(sum(d.score), 0)::bigint,
         coalesce(max(d.streak), 0)::bigint,
         coalesce(sum(d.rooms), 0)::bigint,
         count(*)
  into v_score, v_streak, v_rooms, v_n
  from public.player_score_daily d
  where d.player_id = p_player_id;

  if v_n = 0 then
    delete from public.player_score_total t where t.player_id = p_player_id;
  else
    insert into public.player_score_total as t (player_id, score, streak, rooms)
    values (p_player_id, v_score, v_streak, v_rooms)
    on conflict (player_id) do update
      set score = excluded.score,
          streak = excluded.streak,
          rooms = excluded.rooms,
          updated_at = now()
      where (t.score, t.streak, t.rooms)
            is distinct from (excluded.score, excluded.streak, excluded.rooms);
  end if;
end;
$function$;
revoke all on function public.refresh_player_score_total(uuid)
  from public, anon, authenticated;

-- Yeniden kurma/onarım (bakım; service_role): oyuncuları ARTAN sırada
-- (günlük tetikleyiciyle aynı kilit sırası) ve her biri oyuncu kilidi altında
-- günlük satırlardan YENİDEN hesaplar (artırma değil; eşzamanlı yenileme ezilmez).
-- Bir işlemde p_limit oyuncu (her biri bir advisory kilit; kilit tablosu
-- sınırlıdır). Döner: işlenen son oyuncu; bitince null. Sonraki parça için
-- p_after olarak verilir.
create or replace function public.rebuild_player_score_total(
  p_after uuid default null, p_limit integer default 1000)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_p uuid;
  v_last uuid;
  v_n integer := 0;
begin
  for v_p in
    select x.player_id
    from (
      select d.player_id from public.player_score_daily d
      where p_after is null or d.player_id > p_after
      union
      select t.player_id from public.player_score_total t
      where p_after is null or t.player_id > p_after
    ) x
    order by x.player_id
    limit greatest(p_limit, 1)
  loop
    perform public.refresh_player_score_total(v_p);
    v_last := v_p;
    v_n := v_n + 1;
  end loop;
  if v_n < greatest(p_limit, 1) then
    return null;
  end if;
  return v_last;
end;
$function$;
revoke all on function public.rebuild_player_score_total(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.rebuild_player_score_total(uuid, integer) to service_role;

-- Bütün oyuncular (parça parça; tek işlemde kilit sınırı için küçük parça).
create or replace function public.rebuild_player_score_total_all()
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_after uuid := null;
begin
  loop
    v_after := public.rebuild_player_score_total(v_after, 500);
    exit when v_after is null;
  end loop;
end;
$function$;
revoke all on function public.rebuild_player_score_total_all()
  from public, anon, authenticated;
grant execute on function public.rebuild_player_score_total_all() to service_role;

-- Dönen imleç: her gece kalan oyuncuların bir dilimi (player_id sırasıyla,
-- sona gelince başa sarar) doğrulanır; böylece eski sapma ve eksik eski
-- toplam da sonunda yakalanır. Son değişenler (günlük satırı son p_days günde
-- değişen ya da toplamı yakın zamanda yazılan) her gece doğrulanır.
create table if not exists public.score_total_reconcile_cursor (
  id integer primary key check (id = 1),
  last_player uuid
);
alter table public.score_total_reconcile_cursor enable row level security;
revoke all on public.score_total_reconcile_cursor from public, anon, authenticated;

-- Sapanlar oyuncu artan sırada oyuncu kilidiyle yeniden yazılır (en çok 2000).
-- Hata günlük mutabakatı bozmaz.
create or replace function public.reconcile_player_score_total(
  p_days integer default 2, p_slice integer default 1000)
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_from date := (now() at time zone 'Europe/Istanbul')::date
                 - (greatest(p_days, 1) - 1);
  v_cursor uuid;
  v_slice uuid[];
  v_players uuid[];
  v_p uuid;
  v_n integer;
begin
  insert into public.score_total_reconcile_cursor (id, last_player)
  values (1, null) on conflict (id) do nothing;
  select c.last_player into v_cursor
  from public.score_total_reconcile_cursor c where c.id = 1;

  -- Dönen dilim: imleçten sonraki ilk p_slice oyuncu (günlük ya da toplam).
  select coalesce(array_agg(x.player_id order by x.player_id), '{}')
  into v_slice
  from (
    select y.player_id
    from (
      (select d.player_id from public.player_score_daily d
       where v_cursor is null or d.player_id > v_cursor
       order by d.player_id limit greatest(p_slice, 1))
      union
      (select t.player_id from public.player_score_total t
       where v_cursor is null or t.player_id > v_cursor
       order by t.player_id limit greatest(p_slice, 1))
    ) y
    order by y.player_id
    limit greatest(p_slice, 1)
  ) x;

  -- Sona geldiysek (dilim dolmadı) imleç başa sarar.
  update public.score_total_reconcile_cursor c
  set last_player = case
        when coalesce(array_length(v_slice, 1), 0) < greatest(p_slice, 1) then null
        else v_slice[array_length(v_slice, 1)] end
  where c.id = 1;

  select coalesce(array_agg(z.player_id order by z.player_id), '{}')
  into v_players
  from (
    select c.player_id
    from (
      select unnest(v_slice) as player_id
      union
      select d.player_id from public.player_score_daily d where d.day >= v_from
      union
      select t.player_id from public.player_score_total t
      where t.updated_at >= now() - make_interval(days => greatest(p_days, 1))
    ) c
    left join lateral (
      select coalesce(sum(d.score), 0)::bigint as score,
             coalesce(max(d.streak), 0)::bigint as streak,
             coalesce(sum(d.rooms), 0)::bigint as rooms,
             count(*) as n
      from public.player_score_daily d
      where d.player_id = c.player_id
    ) e on true
    left join public.player_score_total t on t.player_id = c.player_id
    where (e.n = 0 and t.player_id is not null)
       or (e.n > 0 and (t.player_id is null
           or (t.score, t.streak, t.rooms)
              is distinct from (e.score, e.streak, e.rooms)))
    order by c.player_id
    limit 2000
  ) z;

  v_n := coalesce(array_length(v_players, 1), 0);
  foreach v_p in array v_players loop
    perform public.refresh_player_score_total(v_p);
  end loop;
  if v_n > 0 then
    raise warning 'player_score_total sapması: % oyuncu düzeltildi', v_n;
  end if;
  return v_n;
exception when others then
  raise warning 'reconcile_player_score_total başarısız: %', sqlerrm;
  return -1;
end;
$function$;
revoke all on function public.reconcile_player_score_total(integer, integer)
  from public, anon, authenticated;

-- Bakım: günlük satır yazılınca aynı işlemde toplam da yenilenir.
select pg_temp.tur4_yama(
  'public.recompute_player_score_day(uuid,date)',
  $e$          rooms = excluded.rooms;
  end if;
end;$e$,
  $y$          rooms = excluded.rooms;
  end if;

  -- (2026-11-05 tur 4) tüm zamanlar toplamı: aynı işlemde, oyuncu başına kilit.
  perform public.refresh_player_score_total(p_player_id);
end;$y$);

-- Onarım aracı toplamı da yeniden kurar.
select pg_temp.tur4_yama(
  'public.rebuild_player_score_daily(date)',
  $e$  get diagnostics v_rows = row_count;
  return v_rows;$e$,
  $y$  get diagnostics v_rows = row_count;
  perform public.rebuild_player_score_total_all();
  return v_rows;$y$);

-- Gecelik mutabakat toplam mutabakatını da çağırır.
select pg_temp.tur4_yama(
  'public.reconcile_player_score_daily(integer)',
  $e$  return v_total;
end;$e$,
  $y$  perform public.reconcile_player_score_total(p_days, 1000);
  return v_total;
end;$y$);

-- Okuma: p_days <= 0 (tüm zamanlar) toplam tablosundan, oyuncu başına tek satır.
select pg_temp.tur4_yama(
  'public.leaderboard_daily_rows(integer,uuid[])',
  $e$  from public.player_score_daily a, edge e
  where (e.ts is null or a.day > e.d)
    and (p_player_ids is null or a.player_id = any(p_player_ids))
  union all$e$,
  $y$  from public.player_score_daily a, edge e
  where e.ts is not null and a.day > e.d
    and (p_player_ids is null or a.player_id = any(p_player_ids))
  union all
  select t.player_id, t.score, t.streak, t.rooms
  from public.player_score_total t
  where p_days <= 0
    and (p_player_ids is null or t.player_id = any(p_player_ids))
  union all$y$);

-- Geri doldurma. Yeni bakım yolu (yukarıdaki yama) bu noktadan SONRA kuruludur.
-- 1) Kapsama: eksik satırlar kilitsiz eklenir (var olana dokunmaz; tablo hemen
-- tam görünür). 2) Doğruluk: oyuncular ARTAN sırada, her biri oyuncu kilidi
-- altında günlük satırlardan yeniden hesaplanır (günlük tetikleyiciyle aynı
-- kilit sırası; eşzamanlı yenileme ezilmez). Kilit tablosu sınırlı olduğundan
-- göçte ilk 3000 oyuncu işlenir; kalanı gecelik dönen imleçli mutabakat ya da
-- `select public.rebuild_player_score_total_all()` (ayrı işlemlerde parça
-- parça: rebuild_player_score_total(after, 500)) tamamlar. Göç anında eski
-- tetikleyiciyi çalıştıran ve bu işlemden sonra commit eden bir işlem toplamı
-- güncellemeden günlük satırı yazmış olabilir: onu da aynı mutabakat yakalar.
insert into public.player_score_total (player_id, score, streak, rooms)
select d.player_id,
       coalesce(sum(d.score), 0)::bigint,
       coalesce(max(d.streak), 0)::bigint,
       coalesce(sum(d.rooms), 0)::bigint
from public.player_score_daily d
group by d.player_id
on conflict (player_id) do nothing;
select public.rebuild_player_score_total(null, 3000);

-- ---------------------------------------------------------------------------
-- 2. weekly_league_assign: küme başına satır kilidi, oluşturma kilidi dar
-- ---------------------------------------------------------------------------
select pg_temp.tur4_yama(
  'public.weekly_league_assign(uuid,date)',
  $e$  perform pg_advisory_xact_lock(
    hashtextextended('league-cohort:' || p_week::text || ':' || v_tier::text, 0));

  -- Kilidi beklerken aynı oyuncu başka çağrıyla yazılmış olabilir.
  select m.cohort_id into v_cohort
  from public.weekly_league_members m
  where m.week_start = p_week and m.player_id = p_player_id;
  if v_cohort is not null then
    return v_cohort;
  end if;

  select c.id into v_cohort
  from public.weekly_league_cohorts c
  where c.week_start = p_week and c.tier = v_tier and c.member_count < 30
  order by c.created_at, c.id
  limit 1
  for update;

  if v_cohort is null then
    insert into public.weekly_league_cohorts (week_start, tier, member_count)
    values (p_week, v_tier, 0)
    returning id into v_cohort;
  end if;
$e$,
  $y$  -- (2026-11-05 tur 4) Aynı oyuncunun çift çağrısı sıraya girer; başka
  -- oyuncuyla çakışmaz.
  perform pg_advisory_xact_lock(
    hashtextextended('league-player:' || p_week::text || ':' || p_player_id::text, 0));

  select m.cohort_id into v_cohort
  from public.weekly_league_members m
  where m.week_start = p_week and m.player_id = p_player_id;
  if v_cohort is not null then
    return v_cohort;
  end if;

  -- 1) Kilitsiz yol: dolmamış ve başka işlemde KİLİTLİ OLMAYAN küme.
  select c.id into v_cohort
  from public.weekly_league_cohorts c
  where c.week_start = p_week and c.tier = v_tier and c.member_count < 30
  order by c.created_at, c.id
  limit 1
  for update skip locked;

  if v_cohort is null then
    -- 2) Uygun küme yok: yalnız (hafta, kademe) küme oluşturma kilidi. Kilit
    -- altında kümeler BEKLEYEREK aranır (başkası doldurduysa o kümeye girilir),
    -- yoksa yeni küme açılır.
    perform pg_advisory_xact_lock(
      hashtextextended('league-cohort-create:' || p_week::text || ':' || v_tier::text, 0));

    select c.id into v_cohort
    from public.weekly_league_cohorts c
    where c.week_start = p_week and c.tier = v_tier and c.member_count < 30
    order by c.created_at, c.id
    limit 1
    for update;

    if v_cohort is null then
      insert into public.weekly_league_cohorts (week_start, tier, member_count)
      values (p_week, v_tier, 0)
      returning id into v_cohort;
    end if;
  end if;
$y$);

commit;
