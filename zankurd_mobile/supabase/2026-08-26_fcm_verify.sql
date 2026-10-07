select
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'fcm_token'
  ) as has_fcm_column,
  to_regclass('public.push_outbox') is not null as has_outbox,
  exists (select 1 from pg_proc where proname = 'set_fcm_token') as has_set_token,
  exists (select 1 from pg_proc where proname = 'claim_push_outbox') as has_claim;
