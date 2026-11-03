-- Haftalık lig (Duolingo tarzı kümeler). Canlıda (2026-11-04/05, applied.md ✅).
-- Geri alma: geri_al/2026-11-05_haftalik_lig_geri.sql
--
-- Niçin: tek global sıralama yeni gelen oyuncuyu bin puanlık liderlerin
-- altında bırakıp bırakma isteği doğurur (kurul bulgusu). Lig, oyuncuyu aynı
-- kademeden en çok 30 kişilik haftalık bir kümeye koyar; rakipler yakın
-- puanlıdır, ilk 5 üst kademeye çıkar, son 5 alta düşer.
--
-- Eski `2026-07-10_weekly_league.sql` (league_weeks / league_memberships,
-- 3 kademe, UTC haftası, bayrak kapalı) ile ÇAKIŞMAZ: bu göçün nesneleri
-- `weekly_league_*` adlıdır ve eski tablolara dokunmaz.
--
-- Puan kaynağı: `player_score_daily` (2026-11-04_olcek_sertlestirme.sql, canlı)
-- = sıralamayla aynı oda tabanlı toplam. Küme sorgusu yalnız küme üyelerinin
-- (en çok 30 oyuncu x 7 gün) satırlarını okur; oda tablosuna dokunmaz.
--
-- Hafta: İstanbul pazartesi 00:00 -> sonraki pazartesi 00:00.
-- Kademe: 0 Bronz, 1 Gümüş, 2 Altın, 3 Elmas, 4 Efsane (adlar istemcide).
-- Küme ataması tembeldir: oyuncu haftada ilk kez puan aldıktan sonra
-- `get_my_league()` çağırınca, kendi kademesindeki dolmamış kümeye girer.
-- Hafta sonu kapanışı pg_cron ile pazartesi 00:05 İstanbul (= pazar 21:05 UTC;
-- Türkiye yıl boyu UTC+3). Cron kaçarsa ilk `get_my_league()` geçen haftayı
-- kendisi kapatır; kapanış hafta başına bir kez çalışır (idempotent).

begin;

create extension if not exists pg_cron with schema pg_catalog;

-- ---------------------------------------------------------------------------
-- 1. Tablolar (RLS açık, istemciye doğrudan yetki yok; erişim RPC ile)
-- ---------------------------------------------------------------------------
create table if not exists public.weekly_league_cohorts (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  tier smallint not null check (tier between 0 and 4),
  member_count integer not null default 0 check (member_count between 0 and 30),
  created_at timestamptz not null default now()
);
-- Dolmamış küme araması (hafta, kademe) için.
create index if not exists weekly_league_cohorts_open_idx
  on public.weekly_league_cohorts (week_start, tier, created_at)
  where member_count < 30;

-- Oyuncunun kalıcı kademesi; yalnız kapanış yazar. Satır yoksa Bronz.
create table if not exists public.weekly_league_players (
  player_id uuid primary key references public.profiles(id) on delete cascade,
  tier smallint not null default 0 check (tier between 0 and 4),
  updated_at timestamptz not null default now()
);

create table if not exists public.weekly_league_members (
  week_start date not null,
  player_id uuid not null references public.profiles(id) on delete cascade,
  cohort_id uuid not null references public.weekly_league_cohorts(id) on delete cascade,
  tier smallint not null check (tier between 0 and 4),
  joined_at timestamptz not null default now(),
  final_rank integer,
  final_score bigint,
  outcome text check (outcome in ('promoted', 'demoted', 'stayed')),
  new_tier smallint check (new_tier between 0 and 4),
  result_seen boolean not null default false,
  primary key (week_start, player_id)
);
-- Küme sıralaması ve kapanış (küme -> üyeler) için.
create index if not exists weekly_league_members_cohort_idx
  on public.weekly_league_members (cohort_id);
-- "Son sonucum" araması için.
create index if not exists weekly_league_members_player_idx
  on public.weekly_league_members (player_id, week_start desc);

-- Kapanış kaydı: hafta başına tek satır (idempotency anahtarı).
create table if not exists public.weekly_league_closed (
  week_start date primary key,
  closed_at timestamptz not null default now()
);

alter table public.weekly_league_cohorts enable row level security;
alter table public.weekly_league_players enable row level security;
alter table public.weekly_league_members enable row level security;
alter table public.weekly_league_closed enable row level security;
revoke all on public.weekly_league_cohorts from public, anon, authenticated;
revoke all on public.weekly_league_players from public, anon, authenticated;
revoke all on public.weekly_league_members from public, anon, authenticated;
revoke all on public.weekly_league_closed from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Yardımcılar
-- ---------------------------------------------------------------------------
-- İstanbul haftasının pazartesi günü.
create or replace function public.weekly_league_week_start(p_ts timestamptz default now())
returns date
language sql
stable
set search_path to 'public', 'pg_temp'
as $function$
  select date_trunc('week', p_ts at time zone 'Europe/Istanbul')::date;
$function$;
revoke all on function public.weekly_league_week_start(timestamptz)
  from public, anon, authenticated;

-- Bölge boyutu: küme >= 4 ise en çok 5, küme/3 kadar (çıkma ve düşme bölgeleri
-- hiçbir kümede çakışmaz); daha küçük kümede bölge yok.
create or replace function public.weekly_league_zone_size(p_size bigint)
returns integer
language sql
immutable
set search_path to 'public', 'pg_temp'
as $function$
  select case when p_size < 4 then 0 else least(5, (p_size / 3)::integer) end;
$function$;
revoke all on function public.weekly_league_zone_size(bigint)
  from public, anon, authenticated;

-- Haftalık puan: sıralamayla aynı toplam tablosu, İstanbul günleri.
create or replace function public.weekly_league_score(p_player_id uuid, p_week date)
returns bigint
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select coalesce(sum(d.score), 0)::bigint
  from public.player_score_daily d
  where d.player_id = p_player_id
    and d.day >= p_week
    and d.day < p_week + 7;
$function$;
revoke all on function public.weekly_league_score(uuid, date)
  from public, anon, authenticated;

-- Oyuncuyu haftanın kümesine yazar (varsa mevcut kümesini döndürür). Kademe
-- başına advisory kilit: aynı kademenin kümesini iki oyuncu aynı anda
-- doldurup 30'u aşamaz.
create or replace function public.weekly_league_assign(p_player_id uuid, p_week date)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_cohort uuid;
  v_tier smallint;
begin
  select m.cohort_id into v_cohort
  from public.weekly_league_members m
  where m.week_start = p_week and m.player_id = p_player_id;
  if v_cohort is not null then
    return v_cohort;
  end if;

  select coalesce(
    (select p.tier from public.weekly_league_players p where p.player_id = p_player_id),
    0)
  into v_tier;

  perform pg_advisory_xact_lock(
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

  insert into public.weekly_league_members (week_start, player_id, cohort_id, tier)
  values (p_week, p_player_id, v_cohort, v_tier);
  update public.weekly_league_cohorts
  set member_count = member_count + 1
  where id = v_cohort;

  return v_cohort;
end;
$function$;
revoke all on function public.weekly_league_assign(uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Hafta kapanışı (cron: pazartesi 00:05 İstanbul)
-- ---------------------------------------------------------------------------
-- İlk 5 üst kademeye çıkar (Efsane'de çıkma yok), son 5 alta düşer (Bronz'da
-- düşme yok: kademe 0'ın altına inmez). Küme >= 4 değilse bölge yoktur. Puanı
-- 0 olan çıkmaz. Kümeye hiç girmemiş (hiç puan almamış) oyuncu kümede olmadığı
-- için düşürülmez; kademesi korunur. Aynı hafta ikinci kez çağrılırsa 0 döner.
create or replace function public.weekly_league_rollover(p_week date default null)
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_week date := coalesce(p_week, public.weekly_league_week_start() - 7);
  v_count integer;
begin
  if v_week <> date_trunc('week', v_week::timestamp)::date then
    raise exception 'weekly_league_rollover: hafta pazartesi olmalı: %', v_week;
  end if;
  if v_week >= public.weekly_league_week_start() then
    raise exception 'weekly_league_rollover: süren ya da gelecek hafta kapatılamaz: %', v_week;
  end if;

  perform pg_advisory_xact_lock(hashtextextended('league-rollover:' || v_week::text, 0));

  insert into public.weekly_league_closed (week_start) values (v_week)
  on conflict (week_start) do nothing;
  if not found then
    return 0;
  end if;

  with scored as (
    select
      m.player_id,
      m.tier,
      coalesce(sc.total, 0)::bigint as score,
      row_number() over (
        partition by m.cohort_id
        order by coalesce(sc.total, 0) desc, m.joined_at asc, m.player_id asc
      ) as rk,
      count(*) over (partition by m.cohort_id) as n
    from public.weekly_league_members m
    left join lateral (
      select sum(d.score) as total
      from public.player_score_daily d
      where d.player_id = m.player_id
        and d.day >= v_week and d.day < v_week + 7
    ) sc on true
    where m.week_start = v_week and m.outcome is null
  ),
  decided as (
    select
      s.*,
      public.weekly_league_zone_size(s.n) as z,
      case
        when s.tier < 4 and s.score > 0
             and s.rk <= public.weekly_league_zone_size(s.n) then 'promoted'
        when s.tier > 0
             and s.rk > s.n - public.weekly_league_zone_size(s.n)
             and public.weekly_league_zone_size(s.n) > 0 then 'demoted'
        else 'stayed'
      end as outcome
    from scored s
  ),
  upd as (
    update public.weekly_league_members m
    set final_rank = d.rk,
        final_score = d.score,
        outcome = d.outcome,
        new_tier = case d.outcome
                     when 'promoted' then d.tier + 1
                     when 'demoted' then d.tier - 1
                     else d.tier end
    from decided d
    where m.week_start = v_week and m.player_id = d.player_id
    returning m.player_id, m.new_tier
  )
  insert into public.weekly_league_players as lp (player_id, tier, updated_at)
  select u.player_id, u.new_tier, now() from upd u
  on conflict (player_id) do update
    set tier = excluded.tier, updated_at = excluded.updated_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;
revoke all on function public.weekly_league_rollover(date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. İstemci RPC'leri
-- ---------------------------------------------------------------------------
-- Oyuncunun kademesi, haftalık küme sıralaması, bölgeler, kalan süre ve
-- (okunmamış) geçen hafta sonucu. Engellenen oyuncular listeden çıkarılır
-- (sıra numaraları kümenin GERÇEK sırasıdır; bölgeler bozulmaz). Haftada henüz
-- puanı yoksa kümeye girmez: joined=false döner.
create or replace function public.get_my_league()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_week date := public.weekly_league_week_start();
  v_cohort uuid;
  v_tier smallint;
  v_size bigint := 0;
  v_rank integer;
  v_score bigint;
  v_members jsonb;
  v_result jsonb;
  v_ends timestamptz;
  v_zone integer;
begin
  if v_uid is null then
    return null;
  end if;

  -- Cron kaçtıysa geçen haftayı burada kapat (idempotent).
  if exists (
       select 1 from public.weekly_league_members m where m.week_start = v_week - 7
     )
     and not exists (
       select 1 from public.weekly_league_closed c where c.week_start = v_week - 7
     ) then
    perform public.weekly_league_rollover(v_week - 7);
  end if;

  select m.cohort_id, m.tier into v_cohort, v_tier
  from public.weekly_league_members m
  where m.week_start = v_week and m.player_id = v_uid;

  if v_cohort is null and public.weekly_league_score(v_uid, v_week) > 0 then
    v_cohort := public.weekly_league_assign(v_uid, v_week);
    select m.tier into v_tier
    from public.weekly_league_members m
    where m.week_start = v_week and m.player_id = v_uid;
  end if;

  if v_tier is null then
    select coalesce(
      (select p.tier from public.weekly_league_players p where p.player_id = v_uid), 0)
    into v_tier;
  end if;

  if v_cohort is not null then
    with s as (
      select m.player_id, m.joined_at, coalesce(sc.total, 0)::bigint as score
      from public.weekly_league_members m
      left join lateral (
        select sum(d.score) as total
        from public.player_score_daily d
        where d.player_id = m.player_id
          and d.day >= v_week and d.day < v_week + 7
      ) sc on true
      where m.cohort_id = v_cohort and m.week_start = v_week
    ),
    r as (
      select s.*,
        row_number() over (order by s.score desc, s.joined_at asc, s.player_id asc) as rk,
        count(*) over () as n
      from s
    )
    select
      coalesce(jsonb_agg(
        jsonb_build_object(
          'rank', r.rk,
          'player_id', r.player_id,
          'display_name', coalesce(p.display_name, 'Oyuncu'),
          'avatar_icon', p.avatar_icon,
          'avatar_color', p.avatar_color,
          'avatar_url', p.avatar_url,
          'avatar_frame', p.avatar_frame,
          'score', r.score,
          'is_me', r.player_id = v_uid
        ) order by r.rk
      ) filter (
        where r.player_id = v_uid
          or not exists (
            select 1 from public.blocked_users b
            where b.blocker_id = v_uid and b.blocked_id = r.player_id
          )
      ), '[]'::jsonb),
      max(r.n),
      max(r.rk) filter (where r.player_id = v_uid),
      max(r.score) filter (where r.player_id = v_uid)
    into v_members, v_size, v_rank, v_score
    from r
    left join public.profiles p on p.id = r.player_id;
  end if;

  v_zone := public.weekly_league_zone_size(v_size);
  v_ends := ((v_week + 7)::timestamp at time zone 'Europe/Istanbul');

  select jsonb_build_object(
    'week_start', m.week_start,
    'outcome', m.outcome,
    'from_tier', m.tier,
    'to_tier', m.new_tier,
    'rank', m.final_rank
  )
  into v_result
  from public.weekly_league_members m
  where m.player_id = v_uid and m.outcome is not null and not m.result_seen
  order by m.week_start desc
  limit 1;

  return jsonb_build_object(
    'tier', v_tier,
    'joined', v_cohort is not null,
    'week_start', v_week,
    'week_ends_at', v_ends,
    'seconds_left', greatest(0, floor(extract(epoch from (v_ends - now()))))::bigint,
    'cohort_size', coalesce(v_size, 0),
    'promote_count', case when v_tier >= 4 then 0 else v_zone end,
    'demote_count', case when v_tier <= 0 then 0 else v_zone end,
    'my_rank', v_rank,
    'my_score', coalesce(v_score, 0),
    'members', coalesce(v_members, '[]'::jsonb),
    'last_result', v_result
  );
end;
$function$;
revoke all on function public.get_my_league() from public, anon;
grant execute on function public.get_my_league() to authenticated;

-- Sonuç kartı kapatılınca çağrılır: yalnız çağıranın satırları "görüldü" olur.
create or replace function public.ack_my_league_result()
returns void
language sql
security definer
set search_path to 'public', 'pg_temp'
as $function$
  update public.weekly_league_members m
  set result_seen = true
  where m.player_id = auth.uid() and m.outcome is not null and not m.result_seen;
$function$;
revoke all on function public.ack_my_league_result() from public, anon;
grant execute on function public.ack_my_league_result() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Zamanlama: pazartesi 00:05 İstanbul = pazar 21:05 UTC (idempotent)
-- ---------------------------------------------------------------------------
select cron.unschedule('weekly-league-rollover')
where exists (select 1 from cron.job where jobname = 'weekly-league-rollover');

select cron.schedule(
  'weekly-league-rollover',
  '5 21 * * 0',
  $$select public.weekly_league_rollover()$$
);

-- Eski lig işi: `finalize-weekly-league` (2026-07-10_weekly_league.sql,
-- 2026-08-26_weekly_league_cron.sql) yalnız league_weeks / league_memberships
-- yazar; jeton, rozet ya da başka ödül VERMEZ (gövdede coin/badge/reward yok).
-- İstemci `get_my_league_state` ve bu tabloları HİÇ okumaz (arayüzü
-- kWeeklyLeagueEnabled=false ile kapalı), yani çıktısını tüketen yok. İki
-- kapanış yarışmasın ve ölü iş boşa çalışmasın diye kaldırılır; tabloların
-- kendisi durur (geri alma işi yeniden kurar). Yeni kapanış de ödül vermez.
select cron.unschedule('finalize-weekly-league')
where exists (select 1 from cron.job where jobname = 'finalize-weekly-league');

commit;
