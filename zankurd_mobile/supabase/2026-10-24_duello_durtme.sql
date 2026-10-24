-- 2026-10-24: DÜELLO DÜRTME + PROFİLDE MAÇ GEÇMİŞİ VE REKORLAR.
--
-- Ürün sahibi onaylı iki özellik, tek göç:
--   1) DÜRTME: turunu bitirmiş oyuncu, rakibi hâlâ oynamadıysa ona bildirim
--      gönderir ("Rakip bekleniyor" satırındaki "Dürt" düğmesi).
--      `nudge_async_duel(p_duel_id)`:
--        * çağıran düelloya KATILMIŞ olmalı (yaratıcı ya da eşleşen rakip),
--        * çağıran turunu BİTİRMİŞ, hedef (rakip ya da kabul etmemiş davetli)
--          bitirmemiş olmalı,
--        * düello 'open'/'matched' ve süresi dolmamış,
--        * düello+gönderici başına 12 saatte en çok 1 dürtme
--          (`async_duel_nudges`, tek satır; yeniden dürtme satırı günceller),
--        * aralarında iki yönlü engel yok,
--        * push_outbox'a `async_duel_turn` satırı (from_user_id = gönderen,
--          böylece send-push tetikleyicisinin engel denetimi de çalışır).
--      Metin iki dilli "KU · TR" (sunucu alıcının dilini bilmiyor).
--      `list_my_async_duels` yeni anahtar `my_nudged_at` (benim son dürtmem)
--      döndürür; istemci kalan bekleme süresini bundan hesaplar. Yeni anahtar
--      ekleme olduğundan eski istemci yok sayar.
--   2) PROFİL MAÇ GEÇMİŞİ: `list_my_recent_matches(p_limit)` çağıranın son
--      bitmiş maçlarını (sırayla düello + canlı oda/1v1) tek listede verir;
--      `get_my_records()` rekorlar için sunucu tarafı sayıları verir. İkisi de
--      yalnız ÇAĞIRANIN verisini okur (SECURITY DEFINER, auth.uid()); ortak
--      iç yardımcı `my_match_history(uuid)` istemciye KAPALIDIR.
--
-- list_my_async_duels gövdesi CANLI tanımdan alındı (2026-10-24, pg_get_
-- functiondef; 2026-10-24_duello_sirasi.sql ile birebir aynıydı); tek fark
-- `async_duel_nudges` birleşimi ve `my_nudged_at` anahtarı (işaretli).
--
-- Kanıt: supabase/kanit/2026-10-24_duello_durtme_kanit.sql (begin…rollback).
begin;

-- ═════════════════════════════════════════════════════════════════════════
-- 1) Dürtme kaydı — düello+gönderici başına TEK satır
-- ═════════════════════════════════════════════════════════════════════════
create table if not exists public.async_duel_nudges (
  duel_id uuid not null references public.async_duels(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  last_nudged_at timestamptz not null,
  primary key (duel_id, sender_id)
);
alter table public.async_duel_nudges enable row level security;
revoke all on table public.async_duel_nudges from public, anon, authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 2) nudge_async_duel
-- ═════════════════════════════════════════════════════════════════════════
create or replace function public.nudge_async_duel(p_duel_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_duel public.async_duels%rowtype;
  v_target uuid;
  v_last timestamptz;
  v_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id
  for update;

  if not found then
    raise exception 'Duel not found';
  end if;

  if v_uid <> v_duel.creator_id
     and v_uid is distinct from v_duel.opponent_id then
    raise exception 'Not a duel player';
  end if;

  if v_duel.status not in ('open', 'matched')
     or v_duel.expires_at <= v_now then
    raise exception 'Duel closed';
  end if;

  if not exists (
    select 1 from public.async_duel_results r
    where r.duel_id = p_duel_id and r.player_id = v_uid
  ) then
    raise exception 'Finish your turn first';
  end if;

  -- Hedef: yaratıcıysam eşleşen rakip (yoksa davetli arkadaş), değilsem yaratıcı.
  v_target := case
    when v_uid = v_duel.creator_id
      then coalesce(v_duel.opponent_id, v_duel.invited_id)
    else v_duel.creator_id
  end;

  if v_target is null then
    raise exception 'No opponent to nudge';
  end if;

  if exists (
    select 1 from public.async_duel_results r
    where r.duel_id = p_duel_id and r.player_id = v_target
  ) then
    raise exception 'Opponent already finished';
  end if;

  if exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = v_uid and b.blocked_id = v_target)
       or (b.blocker_id = v_target and b.blocked_id = v_uid)
  ) then
    raise exception 'Blocked';
  end if;

  -- 12 saatte en çok 1: satır kilitlenir, eşzamanlı çift dokunuş tek geçer.
  select n.last_nudged_at into v_last
  from public.async_duel_nudges n
  where n.duel_id = p_duel_id and n.sender_id = v_uid
  for update;

  if v_last is not null and v_last > v_now - interval '12 hours' then
    raise exception 'Nudge cooldown';
  end if;

  insert into public.async_duel_nudges (duel_id, sender_id, last_nudged_at)
  values (p_duel_id, v_uid, v_now)
  on conflict (duel_id, sender_id)
  do update set last_nudged_at = excluded.last_nudged_at;

  select coalesce(nullif(btrim(left(p.display_name, 40)), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = v_uid;
  v_name := coalesce(v_name, 'ZanKurd');

  insert into public.push_outbox (to_user_id, kind, title, body, from_user_id)
  values (
    v_target,
    'async_duel_turn',
    'ZanKurd',
    -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli.
    'Dora te ye: ' || v_name || ' li benda te ye · Sıra sende: '
      || v_name || ' seni bekliyor',
    v_uid
  );

  return jsonb_build_object(
    'nudged_at', v_now,
    'next_at', v_now + interval '12 hours'
  );
end;
$function$;

revoke all on function public.nudge_async_duel(uuid) from public, anon;
grant execute on function public.nudge_async_duel(uuid) to authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 3) list_my_async_duels — canlı gövde + `my_nudged_at` (işaretli)
-- ═════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.list_my_async_duels()
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select jsonb_build_object(
    'duel_id', d.id,
    'status', d.status,
    'role', case when d.creator_id = v_uid then 'creator' else 'opponent' end,
    'opponent_name', opponent_profile.display_name,
    'opponent_id', opponent_profile.id,
    'category_name', cat.name,
    'my_correct', mine.correct_count,
    'opponent_correct', case
      when mine.duel_id is not null
           or d.forfeit_loser_id = v_uid then theirs.correct_count
      else null
    end,
    'outcome', case
      -- Hükmen sonuç (2026-10-24): kaybeden 24 saatte turunu bitirmedi,
      -- bitiren kazanır. Normal karşılaştırmanın önüne geçer.
      when d.forfeit_loser_id is not null then
        case when d.forfeit_loser_id = v_uid then 'loss' else 'win' end
      when mine.duel_id is not null and theirs.duel_id is not null then
        case
          when mine.correct_count > theirs.correct_count then 'win'
          when mine.correct_count < theirs.correct_count then 'loss'
          when mine.total_ms < theirs.total_ms then 'win'
          when mine.total_ms > theirs.total_ms then 'loss'
          else 'draw'
        end
      else null
    end,
    'forfeit', (d.forfeit_loser_id is not null),
    'expires_at', d.expires_at,
    'created_at', d.created_at,
    'completed_at', d.completed_at,
    'seen', (mine.duel_id is null or mine.seen_at is not null),
    'challenge_code', case
      when d.challenge_code is not null
           and (
             d.creator_id = v_uid
             or (d.invited_id = v_uid and d.opponent_id is null)
           )
        then d.challenge_code
      else null
    end,
    'incoming_challenge', (
      d.creator_id <> v_uid
      and d.invited_id = v_uid
      and d.opponent_id is null
    ),
    'invited_name', case
      when d.creator_id = v_uid then invited_profile.display_name
      else null
    end,
    'invited_id', case
      when d.creator_id = v_uid then d.invited_id
      else null
    end,
    -- 2026-10-24 dürtme: benim bu düellodaki son dürtmem (bekleme süresi).
    'my_nudged_at', nud.last_nudged_at
  )
  from public.async_duels d
  left join public.categories cat
    on cat.id = d.category_id
  left join public.async_duel_results mine
    on mine.duel_id = d.id and mine.player_id = v_uid
  left join public.async_duel_results theirs
    on theirs.duel_id = d.id
    and theirs.player_id = case
      when d.creator_id = v_uid then d.opponent_id
      else d.creator_id
    end
  left join public.profiles opponent_profile
    on opponent_profile.id = case
      when d.creator_id = v_uid then d.opponent_id
      else d.creator_id
    end
  left join public.profiles invited_profile
    on invited_profile.id = d.invited_id
  -- 2026-10-24 dürtme: düello+gönderici başına tek satır.
  left join public.async_duel_nudges nud
    on nud.duel_id = d.id and nud.sender_id = v_uid
  where (
      d.creator_id = v_uid
      or d.opponent_id = v_uid
      -- Bana gelen meydan okuma: davetliyim, kabul etmedim (rakip boş),
      -- süresi dolmadı, yaratıcı turunu bitirdi ve aramızda engel yok.
      or (
        d.invited_id = v_uid
        and d.opponent_id is null
        and d.status = 'open'
        and d.expires_at > now()
        and exists (
          select 1 from public.async_duel_results r
          where r.duel_id = d.id and r.player_id = d.creator_id
        )
        and not exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = v_uid and b.blocked_id = d.creator_id)
             or (b.blocker_id = d.creator_id and b.blocked_id = v_uid)
        )
      )
    )
    and d.created_at >= now() - interval '30 days'
  order by d.created_at desc;
end;
$function$;

revoke all on function public.list_my_async_duels() from public, anon;
grant execute on function public.list_my_async_duels() to authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 4) my_match_history — iç yardımcı (istemciye KAPALI)
-- ═════════════════════════════════════════════════════════════════════════
-- Tek kaynak: hem son maçlar hem rekor sayıları buradan okunur, böylece
-- "kazanma oranı" ile listedeki satırlar çelişemez.
--   * Sırayla düello: iki taraf da bitirdi (completed) YA DA hükmen sonuç.
--     Sonuç list_my_async_duels ile aynı kural (doğru sayı, eşitte süre).
--   * Canlı oda: 'finished' ve ended_reason completed/forfeit; rakip = en
--     yüksek puanlı diğer oyuncu. 'room_1v1' (max_players = 2) ile kalabalık
--     'room' ayrı etiketlenir.
-- result: win | loss | draw. forfeit: hükmen sonuç.
create or replace function public.my_match_history(p_uid uuid)
returns table (
  kind text,
  ref_id uuid,
  opponent_id uuid,
  opponent_name text,
  result text,
  forfeit boolean,
  my_score integer,
  opponent_score integer,
  played_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  return query
  select
    'async'::text,
    d.id,
    op.id,
    op.display_name,
    case
      when d.forfeit_loser_id is not null then
        case when d.forfeit_loser_id = p_uid then 'loss' else 'win' end
      when mine.correct_count > theirs.correct_count then 'win'
      when mine.correct_count < theirs.correct_count then 'loss'
      when mine.total_ms < theirs.total_ms then 'win'
      when mine.total_ms > theirs.total_ms then 'loss'
      else 'draw'
    end,
    (d.forfeit_loser_id is not null),
    mine.correct_count,
    theirs.correct_count,
    coalesce(d.completed_at, d.expires_at)
  from public.async_duels d
  left join public.async_duel_results mine
    on mine.duel_id = d.id and mine.player_id = p_uid
  left join public.async_duel_results theirs
    on theirs.duel_id = d.id
   and theirs.player_id = case
     when d.creator_id = p_uid then d.opponent_id else d.creator_id end
  left join public.profiles op
    on op.id = case
      when d.creator_id = p_uid then d.opponent_id else d.creator_id end
  where (d.creator_id = p_uid or d.opponent_id = p_uid)
    and (
      d.forfeit_loser_id is not null
      or (d.status = 'completed'
          and mine.duel_id is not null
          and theirs.duel_id is not null)
    );

  return query
  select
    case when r.max_players = 2 then 'room_1v1' else 'room' end,
    r.id,
    opp.player_id,
    opp_profile.display_name,
    case
      when r.ended_reason = 'forfeit' and r.forfeited_by is not null then
        case when r.forfeited_by = p_uid then 'loss' else 'win' end
      when mine.score > opp.score then 'win'
      when mine.score < opp.score then 'loss'
      else 'draw'
    end,
    (r.ended_reason = 'forfeit' and r.forfeited_by is not null),
    mine.score,
    opp.score,
    coalesce(r.finished_at, r.created_at)
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = p_uid
  cross join lateral (
    select rp.player_id, rp.score
    from public.room_players rp
    where rp.room_id = r.id and rp.player_id <> p_uid
    order by rp.score desc, rp.joined_at, rp.player_id
    limit 1
  ) opp
  left join public.profiles opp_profile on opp_profile.id = opp.player_id
  where r.status = 'finished'
    and r.ended_reason in ('completed', 'forfeit');
end;
$function$;

revoke all on function public.my_match_history(uuid)
  from public, anon, authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 5) list_my_recent_matches — profilde "Son maçlar"
-- ═════════════════════════════════════════════════════════════════════════
create or replace function public.list_my_recent_matches(
  p_limit integer default 10
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select jsonb_build_object(
    'kind', h.kind,
    'id', h.ref_id,
    'opponent_id', h.opponent_id,
    'opponent_name', h.opponent_name,
    'result', h.result,
    'forfeit', h.forfeit,
    'my_score', h.my_score,
    'opponent_score', h.opponent_score,
    'at', h.played_at
  )
  from public.my_match_history(v_uid) h
  order by h.played_at desc, h.ref_id
  limit greatest(1, least(coalesce(p_limit, 10), 50));
end;
$function$;

revoke all on function public.list_my_recent_matches(integer)
  from public, anon;
grant execute on function public.list_my_recent_matches(integer)
  to authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 6) get_my_records — profilde "Rekorlarım" (sunucu tarafı sayılar)
-- ═════════════════════════════════════════════════════════════════════════
-- Düello = sırayla düello + canlı 1v1 (kalabalık oda sayılmaz).
-- best_quiz_streak: canlı odalardaki en uzun art arda doğru serisi;
-- best_contest_correct: günlük yarışta tek günde en çok doğru. Kayıt yoksa
-- null (istemci "—" gösterir).
create or replace function public.get_my_records()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_wins integer;
  v_losses integer;
  v_draws integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select
    count(*) filter (where h.result = 'win'),
    count(*) filter (where h.result = 'loss'),
    count(*) filter (where h.result = 'draw')
  into v_wins, v_losses, v_draws
  from public.my_match_history(v_uid) h
  where h.kind in ('async', 'room_1v1');

  return jsonb_build_object(
    'duel_wins', v_wins,
    'duel_losses', v_losses,
    'duel_draws', v_draws,
    'best_quiz_streak', (
      select max(rp.streak) from public.room_players rp
      where rp.player_id = v_uid
    ),
    'best_contest_correct', (
      select max(ce.correct_count) from public.contest_entries ce
      where ce.user_id = v_uid
    )
  );
end;
$function$;

revoke all on function public.get_my_records() from public, anon;
grant execute on function public.get_my_records() to authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 7) Doğrulama — tutmazsa göç GERİ ALINIR
-- ═════════════════════════════════════════════════════════════════════════
do $verify$
begin
  if pg_get_functiondef('public.list_my_async_duels()'::regprocedure)
       not like '%my_nudged_at%' then
    raise exception 'list_my_async_duels my_nudged_at döndürmüyor';
  end if;
  if has_function_privilege('anon', 'public.nudge_async_duel(uuid)', 'execute')
     or has_function_privilege('anon', 'public.list_my_recent_matches(integer)', 'execute')
     or has_function_privilege('anon', 'public.get_my_records()', 'execute') then
    raise exception 'anon yeni RPC''leri çalıştırabiliyor';
  end if;
  if has_function_privilege('authenticated', 'public.my_match_history(uuid)', 'execute') then
    raise exception 'my_match_history istemciye açık';
  end if;
  if not has_function_privilege('authenticated', 'public.nudge_async_duel(uuid)', 'execute') then
    raise exception 'authenticated nudge_async_duel çalıştıramıyor';
  end if;
  if has_table_privilege('authenticated', 'public.async_duel_nudges', 'select') then
    raise exception 'async_duel_nudges istemciye açık';
  end if;
end
$verify$;

commit;
