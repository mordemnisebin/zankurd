-- YALNIZ yeni, yerel ve boş zankurd_presence_test* veritabanında çalıştır:
-- psql -v ON_ERROR_STOP=1 -d zankurd_presence_test -f tool/presence_smoke.sql
-- T1: eski testler XP zamanını varlık sanıyor, RLS/60 sn/hesap gizliliğini
-- çalıştırmıyordu. Gerçek PostgreSQL ile izolasyon ve yeniden uygulama bekçisi.
\set ON_ERROR_STOP on

do $guard$
begin
  if current_database() not like 'zankurd_presence_test%'
     or (inet_server_addr() is not null and inet_server_addr() not in ('127.0.0.1'::inet, '::1'::inet))
     or to_regclass('public.user_presence') is not null
     or to_regprocedure('public.list_friends()') is not null then
    raise exception 'Only a fresh isolated local zankurd_presence_test database is allowed';
  end if;
end;
$guard$;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;
create schema if not exists auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema public, auth to authenticated, anon;
create table public.friends (id uuid primary key, user_id uuid, friend_id uuid);
alter table public.friends enable row level security;
create policy own_friends on public.friends to authenticated using (user_id = auth.uid());
grant select on public.friends to authenticated;
insert into auth.users values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');
insert into public.friends values
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
 ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001');
-- extra_field canlıda sonradan eklenmiş bir alanı temsil eder; T1 korumalı.
create function public.list_friends()
returns table(id uuid, friend_id uuid, friend_name text, created_at timestamptz,
              total_score integer, last_active_at timestamptz, extra_field text)
language sql stable security invoker set search_path = pg_catalog, public as $$
  select f.id, f.friend_id, 'Rojda'::text, '2026-01-01'::timestamptz,
         17, '2026-01-02'::timestamptz, 'preserved'::text
  from public.friends f where f.user_id = auth.uid();
$$;
grant execute on function public.list_friends() to authenticated;

\ir ../supabase/2026-10-30_presence.sql
\ir ../supabase/2026-10-30_presence.sql

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
do $$ begin
  if public.get_presence_visibility() then raise exception 'Default is not private'; end if;
  perform public.touch_presence();
  if exists(select 1 from public.user_presence) then raise exception 'Opt-out wrote presence'; end if;
  perform public.set_presence_visibility(true);
  perform public.touch_presence();
end $$;

do $$ declare v_seen timestamptz; begin
  select last_seen_at into strict v_seen from public.user_presence where user_id = auth.uid();
  if v_seen is null then raise exception 'Authenticated guest did not touch'; end if;
  perform public.touch_presence();
  if (select last_seen_at from public.user_presence where user_id = auth.uid()) is distinct from v_seen then
    raise exception '60 second throttle failed';
  end if;
  begin
    update public.user_presence set last_seen_at = now();
    raise exception 'Direct write unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
do $$ declare v_row jsonb; v_old jsonb; begin
  select to_jsonb(f) into strict v_row from public.list_friends() f;
  select to_jsonb(f) into strict v_old from public.list_friends_before_presence() f;
  if v_row - 'last_seen_at' is distinct from v_old then raise exception 'Legacy output changed'; end if;
  if v_row->>'last_seen_at' is null then raise exception 'Friend cannot read presence'; end if;
  perform public.touch_presence();
  if exists(select 1 from public.user_presence where user_id = auth.uid()) then
    raise exception 'Touch changed another account or enabled default';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
do $$ begin
  if exists(select 1 from public.user_presence) then raise exception 'Stranger can read presence'; end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select public.set_presence_visibility(false);
select public.touch_presence();
do $$ begin
  if exists(select 1 from public.user_presence where last_seen_at is not null) then
    raise exception 'Disabled presence still has timestamp';
  end if;
  perform public.set_presence_visibility(true);
  perform public.touch_presence();
  if exists(select 1 from public.user_presence where last_seen_at is not null) then
    raise exception 'Toggle bypassed 60 second throttle';
  end if;
  perform public.set_presence_visibility(false);
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
do $$ begin
  if exists(select 1 from public.list_friends() where last_seen_at is not null) then
    raise exception 'Hidden friend leaks timestamp';
  end if;
end $$;

-- Süreyi beklemeden, yalnız fixture sahibiyle son dokunuşu geriye taşı.
reset role;
update public.user_presence set last_touch_at = now() - interval '61 seconds';
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select public.set_presence_visibility(true);
select public.touch_presence();
do $$ begin
  if not exists(select 1 from public.user_presence where last_seen_at > now() - interval '1 second') then
    raise exception 'Touch after cooldown failed';
  end if;
end $$;

set local role anon;
do $$ begin
  begin perform public.touch_presence(); raise exception 'Anon touched';
  exception when insufficient_privilege then null; end;
  begin perform public.set_presence_visibility(true); raise exception 'Anon changed preference';
  exception when insufficient_privilege then null; end;
  begin perform public.get_presence_visibility(); raise exception 'Anon read preference';
  exception when insufficient_privilege then null; end;
  begin perform public.list_friends(); raise exception 'Anon read friends';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
