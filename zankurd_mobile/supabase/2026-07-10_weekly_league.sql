-- Haftalık lig: küme düşme/çıkma (LeagueTier v1 üstü)
-- v1 istemci: haftalık sıralamadan forRank (1-10 Zêr, 11-25 Zîv, gerisi Bronz)
-- Bu SQL: hafta sonu anlık görüntü + kalıcı kademe + yükselme/düşme kaydı.
-- Uygulama: Supabase SQL Editor (onaylı); cron: pg_cron veya harici scheduler.
-- Proje ref: hupivnxgjtsfafulzspo

-- Haftanın UTC pazartesi 00:00 anahtarı (YYYY-MM-DD)
create or replace function public.league_week_start(ts timestamptz default now())
returns date
language sql
immutable
as $$
  select (date_trunc('week', ts at time zone 'UTC')::date);
$$;

create table if not exists public.league_weeks (
  week_start date primary key,
  status text not null default 'open'
    check (status in ('open', 'finalizing', 'closed')),
  finalized_at timestamptz,
  notes text
);

create table if not exists public.league_memberships (
  week_start date not null references public.league_weeks(week_start) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  -- bronz | ziv | zer  (LeagueTier ile hizalı)
  tier text not null check (tier in ('bronz', 'ziv', 'zer')),
  weekly_score bigint not null default 0,
  weekly_rank int,
  previous_tier text check (previous_tier is null or previous_tier in ('bronz', 'ziv', 'zer')),
  promoted boolean not null default false,
  relegated boolean not null default false,
  primary key (week_start, player_id)
);

create index if not exists league_memberships_player_idx
  on public.league_memberships (player_id, week_start desc);

create index if not exists league_memberships_week_rank_idx
  on public.league_memberships (week_start, weekly_rank);

-- RLS: oyuncu kendi satırını okur; yazma yalnız security definer RPC
alter table public.league_weeks enable row level security;
alter table public.league_memberships enable row level security;

drop policy if exists league_weeks_read on public.league_weeks;
create policy league_weeks_read on public.league_weeks
  for select to authenticated, anon using (true);

drop policy if exists league_memberships_read_own on public.league_memberships;
create policy league_memberships_read_own on public.league_memberships
  for select to authenticated
  using (player_id = auth.uid());

-- Sıra → kademe (istemci LeagueTier.forRank ile aynı sözleşme)
create or replace function public.league_tier_for_rank(p_rank int)
returns text
language sql
immutable
as $$
  select case
    when p_rank is null or p_rank <= 0 then 'bronz'
    when p_rank <= 10 then 'zer'
    when p_rank <= 25 then 'ziv'
    else 'bronz'
  end;
$$;

-- Haftalık skor: bitmiş odalardaki toplam puan (son 7 gün UTC)
create or replace function public.finalize_weekly_league(p_week date default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week date := coalesce(p_week, public.league_week_start(now() - interval '1 day'));
  v_from timestamptz := (v_week::timestamptz at time zone 'UTC');
  v_to   timestamptz := v_from + interval '7 days';
  v_count int := 0;
begin
  insert into public.league_weeks (week_start, status)
  values (v_week, 'finalizing')
  on conflict (week_start) do update set status = 'finalizing';

  -- Önceki hafta kademesi (yoksa bronz)
  create temporary table if not exists _prev_tier on commit drop as
  select player_id, tier
  from public.league_memberships
  where week_start = (v_week - 7);

  -- Bu haftanın skorları
  create temporary table if not exists _week_scores on commit drop as
  select
    rp.player_id,
    coalesce(sum(rp.score), 0)::bigint as weekly_score
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where r.status = 'finished'
    and r.finished_at >= v_from
    and r.finished_at < v_to
    and rp.player_id is not null
  group by rp.player_id;

  -- Sıralama + kademe yaz
  delete from public.league_memberships where week_start = v_week;

  insert into public.league_memberships (
    week_start, player_id, tier, weekly_score, weekly_rank,
    previous_tier, promoted, relegated
  )
  select
    v_week,
    s.player_id,
    public.league_tier_for_rank(s.rnk::int),
    s.weekly_score,
    s.rnk::int,
    coalesce(p.tier, 'bronz'),
    public.league_tier_for_rank(s.rnk::int) = 'zer' and coalesce(p.tier, 'bronz') <> 'zer'
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'bronz',
    public.league_tier_for_rank(s.rnk::int) = 'bronz' and coalesce(p.tier, 'bronz') in ('zer', 'ziv')
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'zer'
  from (
    select
      player_id,
      weekly_score,
      rank() over (order by weekly_score desc, player_id) as rnk
    from _week_scores
  ) s
  left join _prev_tier p on p.player_id = s.player_id;

  get diagnostics v_count = row_count;

  update public.league_weeks
  set status = 'closed', finalized_at = now()
  where week_start = v_week;

  return jsonb_build_object(
    'week_start', v_week,
    'players', v_count,
    'status', 'closed'
  );
end;
$$;

revoke all on function public.finalize_weekly_league(date) from public;
grant execute on function public.finalize_weekly_league(date) to service_role;

-- Oyuncunun güncel / son kapanmış kademesi
create or replace function public.get_my_league_state()
returns table (
  week_start date,
  tier text,
  weekly_score bigint,
  weekly_rank int,
  previous_tier text,
  promoted boolean,
  relegated boolean
)
language sql
security definer
set search_path = public
as $$
  select
    m.week_start,
    m.tier,
    m.weekly_score,
    m.weekly_rank,
    m.previous_tier,
    m.promoted,
    m.relegated
  from public.league_memberships m
  where m.player_id = auth.uid()
  order by m.week_start desc
  limit 1;
$$;

grant execute on function public.get_my_league_state() to authenticated;

-- Cron notu (pg_cron yüklüyse — Studio'da ayrı etkinleştir):
-- select cron.schedule(
--   'finalize-weekly-league',
--   '5 0 * * 1',  -- her Pazartesi 00:05 UTC
--   $$ select public.finalize_weekly_league(); $$
-- );
