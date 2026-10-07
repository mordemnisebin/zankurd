-- FCM token + arkadaşlık isteği kuyruğu.
--
-- Kolon tek başına yarım kalır: token yazılır, kimse okuyup göndermez.
-- Bu göç üç halkayı birlikte kurar:
--   1) profiles.fcm_token ve sahibi-yalnız RPC
--   2) push_outbox (istemci okuyamaz)
--   3) friend_requests INSERT → kuyruk
-- Gönderici service_role ile claim_push_outbox çağırır (FCM HTTP v1).
-- Gizli anahtar bu repoda durmaz.

alter table public.profiles
  add column if not exists fcm_token text;

create or replace function public.set_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  if p_token is null or length(trim(p_token)) = 0 then
    update public.profiles set fcm_token = null where id = v_uid;
    return;
  end if;
  update public.profiles set fcm_token = trim(p_token) where id = v_uid;
end;
$$;

revoke all on function public.set_fcm_token(text) from public, anon;
grant execute on function public.set_fcm_token(text) to authenticated;

revoke select (fcm_token) on public.profiles from anon, authenticated;

create table if not exists public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  to_user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  claimed_at timestamptz
);

create index if not exists push_outbox_unclaimed_idx
  on public.push_outbox (created_at)
  where claimed_at is null;

alter table public.push_outbox enable row level security;

create or replace function public.enqueue_friend_request_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_outbox (to_user_id, kind, title, body)
  values (
    new.to_user_id,
    'friend_request',
    'ZanKurd',
    coalesce(nullif(trim(new.from_user_name), ''), 'ZanKurd')
  );
  return new;
end;
$$;

drop trigger if exists trg_friend_request_push on public.friend_requests;
create trigger trg_friend_request_push
  after insert on public.friend_requests
  for each row
  execute function public.enqueue_friend_request_push();

-- Service role worker: unclaimed rows + hedef token.
create or replace function public.claim_push_outbox(p_limit integer default 20)
returns table (
  job_id uuid,
  to_user_id uuid,
  kind text,
  title text,
  body text,
  fcm_token text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with picked as (
    select o.id
    from public.push_outbox o
    where o.claimed_at is null
    order by o.created_at
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update skip locked
  ),
  marked as (
    update public.push_outbox o
    set claimed_at = now()
    from picked
    where o.id = picked.id
    returning o.id, o.to_user_id, o.kind, o.title, o.body
  )
  select
    marked.id,
    marked.to_user_id,
    marked.kind,
    marked.title,
    marked.body,
    p.fcm_token
  from marked
  join public.profiles p on p.id = marked.to_user_id;
end;
$$;

revoke all on function public.claim_push_outbox(integer) from public, anon, authenticated;
