-- salt okunur
-- applied.md içindeki ? / ✅? boşluklarını canlı katalogla doğrular.
-- Satır sayımı yok; kullanıcı verisi okunmaz.

select
  to_regprocedure('public.spend_coins(integer, text)') is not null
    as spend_coins,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'submit_answer'
  ) as submit_answer,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_leaderboard'
  ) as get_leaderboard,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_daily_spin'
  ) as claim_daily_spin,
  to_regclass('public.league_weeks') is not null as league_weeks,
  to_regclass('public.league_memberships') is not null as league_memberships,
  to_regprocedure('public.league_week_start(timestamptz)') is not null
    as league_week_start,
  to_regprocedure('public.finalize_weekly_league(date)') is not null
    as finalize_weekly_league,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'save_tournament_progress'
  ) as save_tournament_progress,
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rooms'
      and column_name = 'seconds_per_question'
  ) as rooms_seconds_default,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'submit_answer'
      and pg_get_functiondef(p.oid) like '%v_remaining_ratio%'
  ) as submit_answer_has_speed_bonus,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'submit_answer'
      and pg_get_functiondef(p.oid) like '%least(coalesce(p_response_ms%'
  ) as submit_answer_clamps_ms,
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'save_tournament_progress'
      and pg_get_functiondef(p.oid) like '%Tournament stage jump rejected%'
  ) as tournament_stage_jump_guard,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'fcm_token'
  ) as profiles_fcm_token,
  to_regclass('public.shop_items') is not null as shop_items;
