-- ZanKurd release-readiness hardening (forward-only, idempotent)
-- Apply once in Supabase SQL Editor, then mark applied.md as verified.

-- Contest scores and badges must only be written through SECURITY DEFINER RPCs.
do $$
begin
  if to_regclass('public.contest_entries') is not null then
    execute 'drop policy if exists "contest_entries_insert_own" on public.contest_entries';
    execute 'drop policy if exists "contest_entries_update_own" on public.contest_entries';
  end if;
  if to_regclass('public.user_contest_badges') is not null then
    execute 'drop policy if exists "user_contest_badges_insert_own" on public.user_contest_badges';
  end if;
end
$$;

-- Room chat is private to members (the host is also accepted defensively).
do $$
begin
  if to_regclass('public.room_messages') is not null then
    execute 'drop policy if exists "room_messages_read" on public.room_messages';
    execute 'drop policy if exists "room_messages_insert_own" on public.room_messages';
    execute 'drop policy if exists "room_messages_member_select" on public.room_messages';
    execute 'drop policy if exists "room_messages_member_insert" on public.room_messages';

    execute $policy$
      create policy "room_messages_member_select"
      on public.room_messages for select to authenticated
      using (
        exists (
          select 1 from public.room_players rp
          where rp.room_id = room_messages.room_id
            and rp.player_id = auth.uid()
        )
        or exists (
          select 1 from public.rooms r
          where r.id = room_messages.room_id
            and r.host_id = auth.uid()
        )
      )
    $policy$;

    execute $policy$
      create policy "room_messages_member_insert"
      on public.room_messages for insert to authenticated
      with check (
        sender_id = auth.uid()
        and char_length(btrim(text)) between 1 and 500
        and (
          exists (
            select 1 from public.room_players rp
            where rp.room_id = room_messages.room_id
              and rp.player_id = auth.uid()
          )
          or exists (
            select 1 from public.rooms r
            where r.id = room_messages.room_id
              and r.host_id = auth.uid()
          )
        )
      )
    $policy$;
  end if;
end
$$;

-- Even a future RPC regression cannot accept an answer for a later question.
create or replace function public.enforce_current_room_question()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and new.player_id is distinct from auth.uid() then
    raise exception 'Answer player does not match authenticated user';
  end if;

  if not exists (
    select 1
    from public.room_questions rq
    join public.rooms r on r.id = rq.room_id
    where rq.room_id = new.room_id
      and rq.question_id = new.question_id
      and rq.question_index = r.current_question_index
      and r.status = 'active'
  ) then
    raise exception 'Question is not the current active room question';
  end if;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.player_answers') is not null then
    execute 'drop trigger if exists player_answers_current_question_trg on public.player_answers';
    execute $trigger$
      create trigger player_answers_current_question_trg
      before insert on public.player_answers
      for each row execute function public.enforce_current_room_question()
    $trigger$;
  end if;
end
$$;

-- Keep leaderboard payloads bounded while preserving the app's current shape.
drop function if exists public.get_leaderboard(integer, integer);
create function public.get_leaderboard(
  p_days integer default -1,
  p_limit integer default 10
) returns table (
  player_id uuid,
  display_name text,
  total_score bigint,
  best_streak bigint,
  rooms_played bigint,
  avatar_icon text,
  avatar_color text,
  avatar_url text,
  avatar_frame text,
  showcase_title text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(rp.score), 0),
    coalesce(max(rp.streak), 0),
    count(distinct rp.room_id),
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
  group by
    rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  order by coalesce(sum(rp.score), 0) desc,
    coalesce(max(rp.streak), 0) desc,
    count(distinct rp.room_id) desc
  limit least(greatest(p_limit, 1), 100);
$$;

revoke all on function public.get_leaderboard(integer, integer) from public;
grant execute on function public.get_leaderboard(integer, integer)
  to anon, authenticated;

-- Serialize coin spending per player and accept only server-priced reasons.
create or replace function public.spend_coins(p_amount integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_balance integer;
  v_expected integer;
  v_item_id text;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  v_expected := case p_reason
    when 'wildcard_fifty_fifty' then 20
    when 'wildcard_audience' then 30
    when 'wildcard_double_answer' then 50
    when 'wildcard_change_question' then 40
    when 'streak_freeze' then 50
    else null
  end;

  if left(p_reason, 9) = 'purchase_' then
    v_item_id := substring(p_reason from 10);
    select cost into v_expected
    from public.shop_items
    where id = v_item_id;
  end if;

  if p_amount <= 0
     or v_expected is null
     or v_expected <= 0
     or p_amount is distinct from v_expected then
    return jsonb_build_object('success', false, 'error', 'invalid price');
  end if;

  -- The profile row is the per-user mutex for concurrent purchases.
  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  if v_item_id is not null
     and v_item_id <> 'spin_wheel_extra'
     and exists (
       select 1
       from public.coin_transactions
       where player_id = v_uid
         and reason = p_reason
         and amount < 0
     ) then
    return jsonb_build_object('success', false, 'error', 'already purchased');
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions
  where player_id = v_uid;

  if v_balance < v_expected then
    return jsonb_build_object('success', false, 'balance', v_balance);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_expected, p_reason);
  return jsonb_build_object(
    'success', true,
    'balance', v_balance - v_expected
  );
end;
$$;

revoke all on function public.spend_coins(integer, text) from public, anon;
grant execute on function public.spend_coins(integer, text) to authenticated;

-- A spin entitlement must come from a fully paid, server-priced purchase.
-- The profile row serializes concurrent claims for the same player.
create or replace function public.claim_extra_spin()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_purchased integer;
  v_used integer;
  v_spin_cost integer;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
  v_reward integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  select cost into v_spin_cost
  from public.shop_items
  where id = 'spin_wheel_extra';
  if v_spin_cost is null or v_spin_cost <= 0 then
    return jsonb_build_object('amount', 0, 'error', 'invalid catalog price');
  end if;

  select count(*) into v_purchased
  from public.coin_transactions
  where player_id = v_uid
    and reason = 'purchase_spin_wheel_extra'
    and amount < 0
    and amount = -v_spin_cost;

  select count(*) into v_used
  from public.coin_transactions
  where player_id = v_uid
    and reason in ('extra_spin:server', 'daily_spin:extra_purchase');

  if v_purchased <= v_used then
    return jsonb_build_object('amount', 0, 'no_spins', true);
  end if;

  v_reward := v_rewards[1 + floor(random() * array_length(v_rewards, 1))::int];
  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, v_reward, 'extra_spin:server');
  return jsonb_build_object('amount', v_reward, 'no_spins', false);
end;
$$;

revoke all on function public.claim_extra_spin() from public, anon;
grant execute on function public.claim_extra_spin() to authenticated;

-- VIP is a paid shop cosmetic. Direct profile updates cannot mint it.
create or replace function public.protect_paid_profile_cosmetics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_changed boolean;
begin
  if tg_op = 'INSERT' then
    v_changed := true;
  else
    v_changed := new.showcase_title is distinct from old.showcase_title;
  end if;

  if new.showcase_title = 'VIP'
     and v_changed
     and not exists (
       select 1
       from public.coin_transactions ct
       join public.shop_items si on si.id = 'profile_badge_vip'
       where ct.player_id = new.id
         and ct.reason = 'purchase_profile_badge_vip'
         and ct.amount < 0
         and ct.amount = -si.cost
     ) then
    raise exception 'VIP badge has not been purchased';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_paid_cosmetics_trg on public.profiles;
create trigger profiles_paid_cosmetics_trg
before insert or update on public.profiles
for each row execute function public.protect_paid_profile_cosmetics();
