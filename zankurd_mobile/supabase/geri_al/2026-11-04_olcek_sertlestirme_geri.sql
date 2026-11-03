-- Geri alma: 2026-11-04_olcek_sertlestirme.sql
-- Sıralama işlevlerini 2026-11-03_siralama_t1.sql canlı tanımlarına, uyandırma
-- işlevini 2026-10-31_push_delivery_v2.sql tanımına, politika ve öneri
-- tetikleyicisini önceki tanımlarına döndürür; global room-membership kilidini
-- geri koyar ve yeni nesneleri kaldırır. Eski global kilit ve yeni kullanıcı
-- başına kilit aynı anda tutulmasın diye uygulamadan önce kısa bakım penceresi
-- önerilir (açık işlemler bitsin).
begin;

set local lock_timeout = '10s';

create or replace function pg_temp.olcek_geri(p_imza text, p_yamali text, p_asil text)
returns void language plpgsql as $geri$
declare
  v_def text;
  v_adet integer;
begin
  v_def := pg_get_functiondef(to_regprocedure(p_imza));
  if v_def is null then
    raise exception 'olcek geri: işlev yok: %', p_imza;
  end if;
  if position(p_yamali in v_def) = 0 then
    return;
  end if;
  v_adet := (length(v_def) - length(replace(v_def, p_yamali, ''))) / length(p_yamali);
  if v_adet <> 1 then
    raise exception 'olcek geri: % için yamalı metin % kez bulundu (1 beklenir)', p_imza, v_adet;
  end if;
  execute replace(v_def, p_yamali, p_asil);
end;
$geri$;

select pg_temp.olcek_geri(
  'public.invite_friends_to_room(uuid,uuid[])',
  E'  perform pg_advisory_xact_lock(hashtextextended(''invite:'' || v_uid::text, 0));\n\n'
  '  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).',
  '  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).');

select pg_temp.olcek_geri(
  'public.add_friend(uuid,text)',
  E'  -- Saatte en çok 50 çağrı (2026-11-04 ölçek sertleştirme).\n'
  '  if not public.rate_limit_hit(''add_friend'', 50, interval ''1 hour'') then\n'
  '    return query select false, ''Too many friend requests''::text;\n'
  '    return;\n'
  '  end if;\n\n'
  '  -- Engelleme (2026-10-02 M5): iki yönden biri engelliyse istek gitmez.',
  '  -- Engelleme (2026-10-02 M5): iki yönden biri engelliyse istek gitmez.');

select pg_temp.olcek_geri(
  'public.create_room_rematch(uuid)',
  E'  perform pg_advisory_xact_lock(hashtextextended(''room-membership:'' || v_uid::text, 0));\n\n'
  '  select * into v_room\n  from public.rooms\n  where id = p_room_id\n  for update;',
  E'  select * into v_room\n  from public.rooms\n  where id = p_room_id\n  for update;');

select pg_temp.olcek_geri(
  'public.create_room_rematch(uuid)',
  $y$-- (2026-11-04) Üyelik kilidi artık işlevin başında (kilit sırası).
  perform 1;$y$,
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$);

select pg_temp.olcek_geri(
  'public.delete_my_account()',
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_user_id::text, 0));$y$,
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$);

select pg_temp.olcek_geri(
  'public.cleanup_stale_rooms()',
  $y$-- (2026-11-04) Global üyelik kilidi kaldırıldı: bu işlev üyelik kabul etmez,
  -- odaları `for update skip locked` satır kilidiyle kapatır.
  perform 1;$y$,
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$);

select pg_temp.olcek_geri(
  'public.join_matchmaking(text)',
  E'  if v_opponent is not null then\n'
  '    if not pg_try_advisory_xact_lock(\n'
  '             hashtextextended(''room-membership:'' || v_opponent::text, 0))\n'
  '       or exists (\n'
  '         select 1\n'
  '         from public.room_players opp_player\n'
  '         join public.rooms opp_room on opp_room.id = opp_player.room_id\n'
  '         where opp_player.player_id = v_opponent\n'
  '           and opp_player.left_at is null\n'
  '           and opp_room.status in (''lobby'', ''active'')\n'
  '       ) then\n'
  '      v_opponent := null;\n'
  '    end if;\n'
  '  end if;\n\n'
  '  if v_opponent is null then\n    insert into public.matchmaking_queue (',
  E'  if v_opponent is null then\n    insert into public.matchmaking_queue (');

select pg_temp.olcek_geri(
  'public.join_matchmaking(text)',
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_player_id::text, 0));$y$,
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$);

select pg_temp.olcek_geri(
  'public.join_room_by_code(text)',
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_uid::text, 0));$y$,
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$);

select pg_temp.olcek_geri(
  'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  E'  -- Saatte en çok 30 yeni oda (2026-11-04 ölçek sertleştirme).\n'
  '  if not public.rate_limit_hit(''room_create'', 30, interval ''1 hour'') then\n'
  '    raise exception ''Too many rooms created'' using errcode = ''ZK429'';\n'
  '  end if;\n\n'
  '  loop\n    v_attempt := v_attempt + 1;',
  E'  loop\n    v_attempt := v_attempt + 1;');

select pg_temp.olcek_geri(
  'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  $y$perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_uid::text, 0));$y$,
  $e$perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));$e$);

-- Eski içerik: sıralama işlevleri 2026-11-03_siralama_t1.sql tanımlarına döner.
create or replace function public.get_leaderboard(p_days integer default -1, p_limit integer default 10)
returns table(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      coalesce(sum(rp.score), 0)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  )
  select
    pd.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(pd.day_score), 0)::bigint,
    coalesce(max(pd.day_streak), 0)::bigint,
    coalesce(sum(pd.day_rooms), 0)::bigint,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from per_day pd
  left join public.profiles p on p.id = pd.player_id
  group by
    pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(pd.day_score), 0) > 0
  order by coalesce(sum(pd.day_score), 0) desc,
    coalesce(max(pd.day_streak), 0) desc,
    coalesce(sum(pd.day_rooms), 0) desc,
    pd.player_id asc
  limit least(greatest(p_limit, 1), 100);
$function$;

create or replace function public.get_my_leaderboard_rank(p_days integer default -1)
returns table(rank bigint, player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      coalesce(sum(rp.score), 0)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0
        or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  ),
  board as (
    select
      pd.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(pd.day_score), 0)::bigint as total_score,
      coalesce(max(pd.day_streak), 0)::bigint as best_streak,
      coalesce(sum(pd.day_rooms), 0)::bigint as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from per_day pd
    left join public.profiles p on p.id = pd.player_id
    group by
      pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(pd.day_score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc,
          b.player_id asc
      ) as row_no
    from board b
  )
  select
    o.row_no as rank,
    o.player_id,
    o.display_name,
    o.total_score,
    o.best_streak,
    o.rooms_played,
    o.avatar_icon,
    o.avatar_color,
    o.avatar_url,
    o.avatar_frame,
    o.showcase_title
  from ordered o
  where o.player_id = auth.uid()
  limit 1;
$function$;

create or replace function public.get_friends_leaderboard(p_days integer default -1)
returns table(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, experience bigint, is_self boolean)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with visible_players as (
    select f.friend_id as player_id
    from public.friends f
    where f.user_id = auth.uid()
      and not exists (
        select 1
        from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = f.friend_id
      )
    union
    select auth.uid()
    where auth.uid() is not null
  ),
  per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      coalesce(sum(rp.score), 0)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join visible_players vp on vp.player_id = rp.player_id
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  )
  select
    vp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(pd.day_score), 0)::bigint,
    coalesce(max(pd.day_streak), 0)::bigint,
    coalesce(sum(pd.day_rooms), 0)::bigint,
    coalesce(p.xp, 0)::bigint,
    vp.player_id = auth.uid()
  from visible_players vp
  left join per_day pd on pd.player_id = vp.player_id
  left join public.profiles p on p.id = vp.player_id
  group by vp.player_id, p.display_name, p.xp
  order by
    coalesce(sum(pd.day_score), 0) desc,
    coalesce(max(pd.day_streak), 0) desc,
    coalesce(sum(pd.day_rooms), 0) desc,
    vp.player_id asc;
$function$;


revoke all on function public.get_leaderboard(integer, integer) from public, anon;
grant execute on function public.get_leaderboard(integer, integer) to authenticated;
revoke all on function public.get_my_leaderboard_rank(integer) from public, anon;
grant execute on function public.get_my_leaderboard_rank(integer) to authenticated;
revoke all on function public.get_friends_leaderboard(integer) from public, anon;
grant execute on function public.get_friends_leaderboard(integer) to authenticated;

drop trigger if exists trg_rooms_score_daily on public.rooms;
drop function if exists public.on_room_score_daily();
drop function if exists public.leaderboard_daily_rows(integer, uuid[]);
drop function if exists public.rebuild_player_score_daily(date);
drop function if exists public.recompute_player_score_day(uuid, date);
drop table if exists public.player_score_daily;
drop index if exists public.idx_rooms_finished_at_finished;
drop function if exists public.score_day_of(timestamptz);

create or replace function public.limit_suggested_question_rate()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_recent integer;
begin
  if auth.uid() is null then
    return new;
  end if;

  select count(*)::integer into v_recent
  from (
    select 1
    from public.suggested_questions s
    where s.user_id = new.user_id
      and s.created_at > now() - interval '24 hours'
    limit 10
  ) recent;

  if v_recent >= 10 then
    raise exception 'suggestion_rate_limited' using errcode = 'ZK429';
  end if;
  return new;
end;
$function$;

revoke all on function public.limit_suggested_question_rate()
  from public, anon, authenticated;


drop policy if exists room_messages_member_select on public.room_messages;

create policy room_messages_member_select
on public.room_messages
for select
to authenticated
using (
  (
    exists (
      select 1
      from public.room_players rp
      where rp.room_id = room_messages.room_id
        and rp.player_id = auth.uid()
    )
    or exists (
      select 1
      from public.rooms r
      where r.id = room_messages.room_id
        and r.host_id = auth.uid()
    )
  )
  and not exists (
    select 1
    from public.blocked_users b
    where b.blocker_id = auth.uid()
      and b.blocked_id = room_messages.sender_id
  )
);


drop index if exists public.idx_room_messages_room_created;

create or replace function public.wake_push_delivery_v2()
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
alter table public.push_delivery_v2_config drop column if exists last_wake_at;

drop function if exists public.rate_limit_hit(text, integer, interval);
drop table if exists public.rate_limit_events;

commit;
