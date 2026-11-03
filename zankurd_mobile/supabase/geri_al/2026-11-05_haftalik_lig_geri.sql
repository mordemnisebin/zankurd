-- Geri alma: 2026-11-05_haftalik_lig.sql
-- Cron işini, RPC'leri, yardımcıları ve yeni lig tablolarını kaldırır. Eski
-- 2026-07-10_weekly_league.sql nesnelerine dokunmaz. Tablolardaki hafta
-- sonuçları silinir (küme geçmişi kaybolur; puan kaynağı player_score_daily durur).
begin;

select cron.unschedule('weekly-league-rollover')
where exists (select 1 from cron.job where jobname = 'weekly-league-rollover');

drop function if exists public.ack_my_league_result();
drop function if exists public.get_my_league();
drop function if exists public.weekly_league_rollover(date);
drop function if exists public.weekly_league_assign(uuid, date);
drop function if exists public.weekly_league_score(uuid, date);
drop function if exists public.weekly_league_zone_size(bigint);
drop function if exists public.weekly_league_week_start(timestamptz);

drop table if exists public.weekly_league_closed;
drop table if exists public.weekly_league_members;
drop table if exists public.weekly_league_players;
drop table if exists public.weekly_league_cohorts;

-- Eski lig işini geri kur (2026-08-26_weekly_league_cron.sql ile aynı).
select cron.unschedule('finalize-weekly-league')
where exists (select 1 from cron.job where jobname = 'finalize-weekly-league');
select cron.schedule('finalize-weekly-league', '5 0 * * 1', $$ select public.finalize_weekly_league(); $$);

commit;
