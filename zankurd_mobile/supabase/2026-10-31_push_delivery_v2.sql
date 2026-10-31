-- Push V2: eklemeli lease/ack ve kapalı kurulum kapısı. CANLIYA UYGULANMADI.
-- Mevcut claim/enqueue/oda işlevleri DEĞİŞMEZ. Canlı şema ve claim gövdesi
-- uygulamadan önce ayrıca incelenmeli: docs/push_delivery_v2_rollout.md.
-- İlk kurulum içindir; aynı adla nesne varsa transaction güvenle durur.
begin;

do $preflight$
declare
  r record;
  actual_type text;
  legacy_definition text;
begin
  for r in select * from (values
    ('push_outbox', 'id', 'uuid'), ('push_outbox', 'to_user_id', 'uuid'),
    ('push_outbox', 'from_user_id', 'uuid'), ('push_outbox', 'kind', 'text'),
    ('push_outbox', 'title', 'text'), ('push_outbox', 'body', 'text'),
    ('push_outbox', 'created_at', 'timestamp with time zone'),
    ('push_outbox', 'claimed_at', 'timestamp with time zone'),
    ('profiles', 'id', 'uuid'), ('profiles', 'fcm_token', 'text'),
    ('profiles', 'push_social', 'boolean'), ('profiles', 'push_duel', 'boolean'),
    ('blocked_users', 'blocker_id', 'uuid'), ('blocked_users', 'blocked_id', 'uuid')
  ) as expected(table_name, column_name, type_name)
  loop
    select pg_catalog.format_type(a.atttypid, a.atttypmod) into actual_type
    from pg_catalog.pg_attribute a
    where a.attrelid = to_regclass('public.' || r.table_name)
      and a.attname = r.column_name and a.attnum > 0 and not a.attisdropped;
    if actual_type is distinct from r.type_name then
      raise exception 'push_v2: beklenmeyen alan/tür %.%', r.table_name, r.column_name;
    end if;
  end loop;
  if to_regprocedure('public.claim_push_outbox(integer)') is null
     or to_regclass('vault.decrypted_secrets') is null
     or to_regclass('cron.job') is null
     or to_regprocedure('cron.alter_job(bigint,text,text,text,text,boolean)') is null
     or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    raise exception 'push_v2: eski claim/pg_cron/pg_net/Vault önkoşulu eksik';
  end if;
  select pg_get_functiondef('public.claim_push_outbox(integer)'::regprocedure)
  into legacy_definition;
  -- Bu işaretler canlı incelemenin yerine geçmez; eski gizlilik sürümüyle
  -- yanlışlıkla kurulum yapılmasını engelleyen asgari kontrol.
  if legacy_definition not like '%push_social%'
     or legacy_definition not like '%push_duel%'
     or legacy_definition not like '%blocked_users%'
     or legacy_definition not like '%from_user_id%'
     or legacy_definition not like '%30 minutes%'
     or legacy_definition not like '%24 hours%' then
    raise exception 'push_v2: canlı claim gizlilik tanımı ayrıca incelenmeli';
  end if;
end;
$preflight$;

-- Devam eden eski claim işlemi bitsin; yeni alanların sınırı atomik olsun.
lock table public.push_outbox in share row exclusive mode;

create table public.push_delivery_v2_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false
);
insert into public.push_delivery_v2_config (singleton) values (true);
alter table public.push_delivery_v2_config enable row level security;
revoke all on public.push_delivery_v2_config from public, anon, authenticated, service_role;

alter table public.push_outbox
  add column data jsonb not null default '{}'::jsonb,
  add column claim_token uuid,
  add column lease_until timestamptz,
  add column attempt_count integer not null default 0 check (attempt_count >= 0),
  add column next_attempt_at timestamptz not null default now(),
  add column delivered_at timestamptz,
  add column delivery_status text not null default 'pending'
    check (delivery_status in ('pending', 'leased', 'retry', 'sent', 'skipped', 'failed', 'legacy')),
  add column last_error_code text,
  add column last_outcome text check (last_outcome in ('sent', 'skipped', 'failed', 'retry'));

-- Eski claim'in başarı mı hata mı olduğunu bilmiyoruz: ASLA yeniden oynatma.
update public.push_outbox
set delivery_status = 'legacy', last_error_code = 'legacy_claimed'
where claimed_at is not null;

create index push_outbox_v2_ready_idx
  on public.push_outbox (next_attempt_at, created_at)
  where delivery_status in ('pending', 'retry', 'leased');

-- İlk token kaydı yalnız o alıcının gönderime aday satırlarını arar.
create index push_outbox_v2_recipient_ready_idx
  on public.push_outbox (to_user_id, next_attempt_at)
  where delivery_status in ('pending', 'retry', 'leased');

-- Yalnız V2'ye ait ortak süzgeç: son yerel claim'in tüm gizlilik koşulları.
-- Token burada yok: henüz token almayan kullanıcının işi beklemede kalır.
create function public.push_delivery_v2_allowed(
  p_to_user_id uuid, p_from_user_id uuid, p_kind text, p_created_at timestamptz, p_data jsonb
) returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $allowed$
  select exists (
    select 1 from public.profiles pr
    where pr.id = p_to_user_id
      and not (coalesce(p_kind, '') like 'async\_duel%' and not pr.push_duel)
      and not (coalesce(p_kind, '') in ('friend_request', 'friend_accept', 'room_invite')
               and not pr.push_social)
      and p_created_at >= now() - case when coalesce(p_kind, '') = 'room_invite'
        then interval '30 minutes' else interval '24 hours' end
      -- Eski kimliksiz işler ana ekrana götürür. Kimlikli bir iş her claim'de
      -- AYNI bekleyen davete, alıcıya, gönderene ve açık lobiye ait olmalı.
      and (p_kind is distinct from 'room_invite' or not (p_data ? 'invite_id')
           or exists (
             select 1 from public.room_invites i join public.rooms r on r.id = i.room_id
             where i.id::text = p_data->>'invite_id'
               and i.room_id::text = p_data->>'room_id'
               and i.invitee_id = p_to_user_id and i.inviter_id = p_from_user_id
               and i.status = 'pending' and r.status = 'lobby'
               and i.created_at >= now() - interval '30 minutes'
               and not exists (
                 select 1 from public.blocked_users b
                 where (b.blocker_id = p_to_user_id and b.blocked_id = r.host_id)
                    or (b.blocker_id = r.host_id and b.blocked_id = p_to_user_id)
               ) and not exists (
                 select 1 from public.room_players rp where rp.room_id = i.room_id
                   and rp.player_id = p_to_user_id and rp.left_at is null
               )
           ))
      and not (p_from_user_id is not null and exists (
        select 1 from public.blocked_users b
        where (b.blocker_id = p_to_user_id and b.blocked_id = p_from_user_id)
           or (b.blocker_id = p_from_user_id and b.blocked_id = p_to_user_id)
      ))
  );
$allowed$;
revoke all on function public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)
  from public, anon, authenticated, service_role;

create function public.claim_push_outbox_v2(p_limit integer default 20)
returns table(job_id uuid, to_user_id uuid, kind text, title text, body text,
              fcm_token text, claim_token uuid, attempt_count integer, data jsonb, expires_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, public
as $claim$
declare
  v_now timestamptz := clock_timestamp();
begin
  if not exists (select 1 from public.push_delivery_v2_config c where c.singleton and c.enabled) then
    return;
  end if;
  -- Etkin lease'ye dokunulmaz. Gizlilik, yaş veya 8 deneme sınırı nedeniyle
  -- elenen işler gönderilmeden terminal olur; en çok500, skip locked.
  update public.push_outbox o
  set delivery_status = case when o.attempt_count >= 8 then 'failed' else 'skipped' end,
      lease_until = null, claimed_at = coalesce(o.claimed_at, v_now),
      last_error_code = case when o.attempt_count >= 8 then 'attempts_exhausted' else 'ineligible' end
  where o.id in (
    select q.id from public.push_outbox q
    where q.delivery_status in ('pending', 'retry', 'leased')
      and (q.claimed_at is null or q.claim_token is not null)
      and (q.lease_until is null or q.lease_until <= v_now)
      and (q.attempt_count >= 8 or not public.push_delivery_v2_allowed(
        q.to_user_id, q.from_user_id, q.kind, q.created_at, q.data))
    order by q.created_at limit 500 for update of q skip locked
  );
  return query
  with picked as (
    select o.id from public.push_outbox o
    join public.profiles pr on pr.id = o.to_user_id
    where o.delivery_status in ('pending', 'retry', 'leased')
      -- Eski worker kurulumdan sonra claim yapmışsa da kör replay yok.
      and (o.claimed_at is null or o.claim_token is not null)
      and (o.lease_until is null or o.lease_until <= v_now)
      and o.next_attempt_at <= v_now and o.attempt_count < 8
      and nullif(btrim(pr.fcm_token), '') is not null
      and public.push_delivery_v2_allowed(o.to_user_id, o.from_user_id, o.kind, o.created_at, o.data)
    order by o.created_at, o.id
    limit greatest(1, least(coalesce(p_limit, 20), 20))
    for update of o skip locked
  ), leased as (
    update public.push_outbox o
    set claim_token = gen_random_uuid(), lease_until = v_now + interval '120 seconds',
        attempt_count = o.attempt_count + 1, delivery_status = 'leased',
        claimed_at = coalesce(o.claimed_at, v_now), last_outcome = null
    from picked where o.id = picked.id
    returning o.*
  )
  select l.id, l.to_user_id, l.kind, l.title, l.body, pr.fcm_token,
         l.claim_token, l.attempt_count,
         l.data || case when l.from_user_id is null then '{}'::jsonb
                        else jsonb_build_object('from_user_id', l.from_user_id::text) end,
         l.created_at + case when coalesce(l.kind, '') = 'room_invite'
           then interval '30 minutes' else interval '24 hours' end
  from leased l join public.profiles pr on pr.id = l.to_user_id;
end;
$claim$;
revoke all on function public.claim_push_outbox_v2(integer) from public, anon, authenticated;
grant execute on function public.claim_push_outbox_v2(integer) to service_role;

create function public.finish_push_outbox(
  p_job_id uuid, p_claim_token uuid, p_outcome text,
  p_error_code text default null, p_retry_after_seconds integer default null
) returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $finish$
declare
  v_job public.push_outbox%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if p_outcome is null or p_outcome not in ('sent', 'skipped', 'failed', 'retry')
     or p_claim_token is null then
    return false;
  end if;
  select * into v_job from public.push_outbox o
  where o.id = p_job_id and o.claim_token = p_claim_token for update;
  if not found then return false; end if;
  -- Yanıt kaybında aynı sonuç+lease true; farklı sonuç veya yeni lease false.
  if v_job.last_outcome = p_outcome and v_job.delivery_status <> 'leased' then
    return true;
  end if;
  if v_job.delivery_status <> 'leased' or v_job.lease_until is null or v_job.lease_until <= v_now then
    return false;
  end if;
  update public.push_outbox o
  set delivery_status = case when p_outcome = 'retry' and o.attempt_count >= 8
                            then 'failed' else p_outcome end,
      last_outcome = p_outcome,
      lease_until = null,
      delivered_at = case when p_outcome = 'sent' then v_now else null end,
      next_attempt_at = case when p_outcome = 'retry'
        then v_now + make_interval(secs => greatest(1, coalesce(p_retry_after_seconds, 30)))
        else o.next_attempt_at end,
      last_error_code = case when p_outcome = 'retry' and o.attempt_count >= 8 then 'attempts_exhausted'
        else left(p_error_code, 80) end
  where o.id = p_job_id and o.claim_token = p_claim_token;
  return true;
end;
$finish$;
revoke all on function public.finish_push_outbox(uuid,uuid,text,text,integer) from public, anon, authenticated;
grant execute on function public.finish_push_outbox(uuid,uuid,text,text,integer) to service_role;

-- pg_net isteği ancak transaction COMMIT olunca başlar. URL ve secret yalnız
-- Vault'tan okunur; dönüş değeri yalnız boolean, secret/request-id loglanmaz.
create function public.wake_push_delivery_v2()
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

create function public.on_push_outbox_insert_v2()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $trigger$
begin
  if exists (select 1 from inserted_push_jobs) then
    perform public.wake_push_delivery_v2();
  end if;
  return null;
exception when others then
  return null;
end;
$trigger$;
revoke all on function public.on_push_outbox_insert_v2() from public, anon, authenticated, service_role;
create trigger trg_push_outbox_wake_v2 after insert on public.push_outbox
referencing new table as inserted_push_jobs
for each statement execute function public.on_push_outbox_insert_v2();

-- İlk geçerli token, kuyrukta bekleyen işin son eksik koşulu olabilir.
-- Claim alma/lease verme worker'da kalır. pg_net isteği commit sonrası başlar.
create function public.on_push_token_ready_v2()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $token$
declare
  v_now timestamptz := clock_timestamp();
begin
  if exists (select 1 from public.push_delivery_v2_config c where c.singleton and c.enabled)
     and exists (
       select 1 from public.push_outbox o
       where o.to_user_id = new.id
         and o.delivery_status in ('pending', 'retry', 'leased')
         and o.next_attempt_at <= v_now and o.attempt_count < 8
         and (o.claimed_at is null or o.claim_token is not null)
         and (o.lease_until is null or o.lease_until <= v_now)
         and public.push_delivery_v2_allowed(o.to_user_id, o.from_user_id, o.kind, o.created_at, o.data)
     ) then
    perform public.wake_push_delivery_v2();
  end if;
  return null;
exception when others then
  -- Teslimat hatası token kaydını bozamaz. Kurtarma cron'u yeniden dener.
  return null;
end;
$token$;
revoke all on function public.on_push_token_ready_v2() from public, anon, authenticated, service_role;
create trigger trg_push_token_ready_v2 after update of fcm_token on public.profiles
for each row when (
  nullif(btrim(old.fcm_token), '') is null and nullif(btrim(new.fcm_token), '') is not null
) execute function public.on_push_token_ready_v2();

-- Eski dakika işi korunur ama durur; v2 cron kapı açılana dek no-op.
do $pause$
declare r record;
begin
  for r in select jobid from cron.job where jobname = 'send-push' loop
    perform cron.alter_job(r.jobid, active := false);
  end loop;
end;
$pause$;
select cron.schedule('send-push-v2', '* * * * *', 'select public.wake_push_delivery_v2();');

commit;
