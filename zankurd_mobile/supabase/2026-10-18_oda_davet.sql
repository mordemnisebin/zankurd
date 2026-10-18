-- 2026-10-18: ODAYA ARKADAŞ DAVETİ — kod olmadan, arkadaş listesinden.
--
-- Test kullanıcılarının geri bildirimi: oda sahibi zaten arkadaş olduğu
-- kişilere kodu elle iletmek zorunda kalıyordu. Artık lobideki herhangi bir
-- oyuncu kabul edilmiş arkadaşlarını doğrudan davet eder; davetli hem push
-- bildirimi alır hem de uygulamada "Odaya davet" kartını görür ve tek
-- dokunuşla katılır.
--
-- Tasarım ilkeleri:
--  * Katılım KODU sunucuda YENİDEN yazılmaz: `respond_room_invite` kabulde
--    yalnız oda kodunu döndürür, istemci mevcut `join_room_by_code` yolundan
--    girer. Böylece dolu oda, engel, başka odada olma, jeton şartı gibi bütün
--    kontroller tek yerde kalır.
--  * Yeni tablo (`room_invites`) istemciye yalnız SELECT açar; yazma sadece
--    RPC ile.
--  * Hiçbir mevcut fonksiyon değişmez; `push_outbox`a mevcut şemayla satır
--    eklenir (kind 'room_invite'). send-push'ta değişiklik gerekmez: bildirim
--    dokunuşu uygulamayı açar, bekleyen davet listeden okunur.
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-18_oda_davet.sql
-- Geri alma:
--   drop function if exists public.invite_friends_to_room(uuid, uuid[]);
--   drop function if exists public.list_my_room_invites();
--   drop function if exists public.respond_room_invite(uuid, boolean);
--   drop table if exists public.room_invites;

begin;

create table if not exists public.room_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  inviter_id uuid not null references public.profiles(id) on delete cascade,
  invitee_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'expired')),
  constraint room_invites_room_invitee_key unique (room_id, invitee_id),
  constraint room_invites_not_self check (inviter_id <> invitee_id)
);

create index if not exists room_invites_invitee_pending_idx
  on public.room_invites (invitee_id, created_at desc)
  where status = 'pending';
create index if not exists room_invites_inviter_created_idx
  on public.room_invites (inviter_id, created_at desc);

alter table public.room_invites enable row level security;

revoke all on table public.room_invites from public, anon, authenticated;
grant select on table public.room_invites to authenticated;

drop policy if exists room_invites_select_own on public.room_invites;
create policy room_invites_select_own on public.room_invites
  for select to authenticated
  using (invitee_id = auth.uid() or inviter_id = auth.uid());

-- ---------------------------------------------------------------------
-- 1) invite_friends_to_room
-- ---------------------------------------------------------------------

create or replace function public.invite_friends_to_room(
  p_room_id uuid,
  p_friend_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_ids uuid[];
  v_friend uuid;
  v_count integer := 0;
  v_active integer;
  v_recent integer;
  v_name text;
  v_prev timestamptz;
  v_push boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_room_id is null or p_friend_ids is null
     or coalesce(array_length(p_friend_ids, 1), 0) = 0 then
    return 0;
  end if;

  -- Yinelenenleri ve null'ları at; çağrı başına en çok 20 kişi.
  select coalesce(array_agg(distinct x), '{}') into v_ids
  from unnest(p_friend_ids) as x
  where x is not null and x <> v_uid;
  if coalesce(array_length(v_ids, 1), 0) > 20 then
    raise exception 'Too many invitees';
  end if;

  select r.id, r.status, r.is_custom, r.max_players into v_room
  from public.rooms r
  where r.id = p_room_id
  for share;

  -- Odayı kuran ya da odada AKTİF olan her oyuncu davet edebilir; lobi
  -- dışında (başladı/bitti) davet anlamsız.
  if not found
     or v_room.status <> 'lobby'
     or not exists (
       select 1 from public.room_players rp
       where rp.room_id = p_room_id
         and rp.player_id = v_uid
         and rp.left_at is null
     ) then
    raise exception 'Room not found or already started';
  end if;

  select count(*)::integer into v_active
  from public.room_players rp
  where rp.room_id = p_room_id and rp.left_at is null;

  if v_active >= case
       when v_room.is_custom and v_room.max_players > 2 then v_room.max_players
       else 2
     end then
    raise exception 'Room is full';
  end if;

  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).
  select count(*)::integer into v_recent
  from public.room_invites i
  where i.inviter_id = v_uid
    and i.created_at > now() - interval '1 hour';
  if v_recent + array_length(v_ids, 1) > 100 then
    raise exception 'Too many invites';
  end if;

  select coalesce(nullif(btrim(left(p.display_name, 40)), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = v_uid;
  v_name := coalesce(v_name, 'ZanKurd');

  foreach v_friend in array v_ids loop
    -- Kabul edilmiş arkadaş, iki yönde engelsiz, odada değil. Aksi halde
    -- sessizce atlanır (engel ifşa edilmez; dönen sayı gerçek davetleri söyler).
    if not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = v_friend
       )
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = v_friend)
            or (b.blocker_id = v_friend and b.blocked_id = v_uid)
       )
       or exists (
         select 1 from public.room_players rp
         where rp.room_id = p_room_id
           and rp.player_id = v_friend
           and rp.left_at is null
       ) then
      continue;
    end if;

    -- Bildirim yalnız yeni ya da 2 dakikadan eski davette kuyruklanır:
    -- yeniden dokunuş telefonu titretip durmasın.
    select i.created_at into v_prev
    from public.room_invites i
    where i.room_id = p_room_id and i.invitee_id = v_friend;
    v_push := v_prev is null or v_prev < now() - interval '2 minutes';

    insert into public.room_invites (room_id, inviter_id, invitee_id)
    values (p_room_id, v_uid, v_friend)
    on conflict (room_id, invitee_id) do update
      set inviter_id = excluded.inviter_id,
          status = 'pending',
          created_at = now();

    if v_push then
      insert into public.push_outbox (to_user_id, kind, title, body)
      values (
        v_friend,
        'room_invite',
        'ZanKurd',
        -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli
        -- (enqueue_async_duel_invite_push ile aynı kalıp).
        v_name || ' tu vexwendî odeyê · ' || v_name
          || ' seni odaya davet etti'
      );
    end if;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;

revoke all on function public.invite_friends_to_room(uuid, uuid[])
  from public, anon;
grant execute on function public.invite_friends_to_room(uuid, uuid[])
  to authenticated;

-- ---------------------------------------------------------------------
-- 2) list_my_room_invites
-- ---------------------------------------------------------------------

create or replace function public.list_my_room_invites()
returns table (
  invite_id uuid,
  room_id uuid,
  room_code text,
  inviter_id uuid,
  inviter_name text,
  category_name text,
  player_count integer,
  max_players integer,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- 30 dakikadan eski ya da lobisi kapanmış davetler süresi doldu sayılır.
  update public.room_invites i
  set status = 'expired'
  where i.invitee_id = v_uid
    and i.status = 'pending'
    and (
      i.created_at < now() - interval '30 minutes'
      or not exists (
        select 1 from public.rooms r
        where r.id = i.room_id and r.status = 'lobby'
      )
    );

  return query
  select
    i.id,
    r.id,
    r.code,
    i.inviter_id,
    coalesce(nullif(btrim(left(p.display_name, 40)), ''), 'ZanKurd'),
    coalesce(c.name, 'Ziman'),
    (select count(*)::integer from public.room_players rp
       where rp.room_id = r.id and rp.left_at is null),
    case when r.is_custom and r.max_players > 2 then r.max_players else 2 end,
    i.created_at
  from public.room_invites i
  join public.rooms r on r.id = i.room_id and r.status = 'lobby'
  left join public.categories c on c.id = r.category_id
  left join public.profiles p on p.id = i.inviter_id
  where i.invitee_id = v_uid
    and i.status = 'pending'
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_uid and b.blocked_id = i.inviter_id)
         or (b.blocker_id = i.inviter_id and b.blocked_id = v_uid)
    )
  order by i.created_at desc
  limit 10;
end;
$function$;

revoke all on function public.list_my_room_invites() from public, anon;
grant execute on function public.list_my_room_invites() to authenticated;

-- ---------------------------------------------------------------------
-- 3) respond_room_invite
-- ---------------------------------------------------------------------

create or replace function public.respond_room_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_inv record;
  v_code text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select i.id, i.room_id, i.status, i.created_at into v_inv
  from public.room_invites i
  where i.id = p_invite_id and i.invitee_id = v_uid
  for update;

  if not found then
    raise exception 'Invite not found';
  end if;

  if not coalesce(p_accept, false) then
    update public.room_invites set status = 'declined' where id = v_inv.id;
    return null;
  end if;

  select r.code into v_code
  from public.rooms r
  where r.id = v_inv.room_id and r.status = 'lobby';

  if v_inv.status <> 'pending'
     or v_inv.created_at < now() - interval '30 minutes'
     or v_code is null then
    update public.room_invites set status = 'expired'
    where id = v_inv.id and status = 'pending';
    raise exception 'Invite expired';
  end if;

  update public.room_invites set status = 'accepted' where id = v_inv.id;
  return v_code;
end;
$function$;

revoke all on function public.respond_room_invite(uuid, boolean)
  from public, anon;
grant execute on function public.respond_room_invite(uuid, boolean)
  to authenticated;

-- Doğrulama: nesneler ve yetkiler yerinde mi?
do $$
begin
  if to_regclass('public.room_invites') is null then
    raise exception 'room_invites yok';
  end if;
  if has_table_privilege('authenticated', 'public.room_invites', 'insert')
     or has_table_privilege('authenticated', 'public.room_invites', 'update') then
    raise exception 'room_invites istemciye yazılabilir olmamalı';
  end if;
  if has_function_privilege('anon',
       'public.invite_friends_to_room(uuid, uuid[])', 'execute') then
    raise exception 'anon davet edemez';
  end if;
end $$;

commit;
