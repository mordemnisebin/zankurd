-- Forward-only hotfix: server-authoritative shop pricing and consumable claims.
-- Safe to rerun. Apply after 2026-07-29_release_readiness_hardening.sql.

begin;

-- Coin ledger is readable by its owner but never directly writable by an
-- app client. Every mutation below goes through a SECURITY DEFINER RPC.
alter table public.coin_transactions enable row level security;
drop policy if exists "Users insert their own coin transactions"
  on public.coin_transactions;
drop policy if exists "Users insert their own non-spin coin transactions"
  on public.coin_transactions;
drop policy if exists "Users read their own coin transactions"
  on public.coin_transactions;
create policy "Users read their own coin transactions"
  on public.coin_transactions for select
  to authenticated
  using (player_id = auth.uid());
revoke insert, update, delete on public.coin_transactions
  from public, anon, authenticated;
grant select on public.coin_transactions to authenticated;

-- Immutable server-written entitlements decouple ownership from the current
-- catalog price. Historical rows are backfilled only when they match the
-- server catalog exactly; zero or forged mismatched transactions stay out.
create table if not exists public.shop_purchases (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null references public.shop_items(id) on delete restrict,
  price_paid integer not null check (price_paid > 0),
  coin_transaction_id uuid not null unique
    references public.coin_transactions(id) on delete cascade,
  purchased_at timestamptz not null default now()
);

create index if not exists shop_purchases_player_item_idx
  on public.shop_purchases(player_id, item_id, purchased_at);
create unique index if not exists shop_purchases_nonrepeatable_uidx
  on public.shop_purchases(player_id, item_id)
  where item_id <> 'spin_wheel_extra';

alter table public.shop_purchases enable row level security;
drop policy if exists shop_purchases_select_own on public.shop_purchases;
create policy shop_purchases_select_own
  on public.shop_purchases for select
  to authenticated
  using (player_id = auth.uid());
revoke all on table public.shop_purchases from public, anon, authenticated;
grant select on table public.shop_purchases to authenticated;

insert into public.shop_purchases (
  player_id,
  item_id,
  price_paid,
  coin_transaction_id,
  purchased_at
)
select
  ct.player_id,
  expected.item_id,
  -ct.amount,
  ct.id,
  ct.created_at
from public.coin_transactions ct
join public.profiles p on p.id = ct.player_id
join (
  values
    ('spin_wheel_extra'::text, 200),
    ('avatar_frame_gold'::text, 750),
    ('profile_badge_vip'::text, 1000)
) as expected(item_id, price_paid)
  on ct.reason = 'purchase_' || expected.item_id
join public.shop_items si
  on si.id = expected.item_id
where ct.amount = -expected.price_paid
on conflict do nothing;

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
  v_transaction_id uuid;
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
    if not (
      v_item_id = any (array[
        'spin_wheel_extra',
        'avatar_frame_gold',
        'profile_badge_vip'
      ])
    ) then
      return jsonb_build_object(
        'success', false,
        'error', 'product not available'
      );
    end if;
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

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  if v_item_id is not null
     and v_item_id <> 'spin_wheel_extra'
     and exists (
       select 1
       from public.shop_purchases
       where player_id = v_uid
         and item_id = v_item_id
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
  values (v_uid, -v_expected, p_reason)
  returning id into v_transaction_id;

  if v_item_id is not null then
    insert into public.shop_purchases (
      player_id,
      item_id,
      price_paid,
      coin_transaction_id
    ) values (
      v_uid,
      v_item_id,
      v_expected,
      v_transaction_id
    );
  end if;
  return jsonb_build_object(
    'success', true,
    'balance', v_balance - v_expected
  );
end;
$$;

revoke all on function public.spend_coins(integer, text) from public, anon;
grant execute on function public.spend_coins(integer, text) to authenticated;

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

  select count(*) into v_purchased
  from public.shop_purchases
  where player_id = v_uid
    and item_id = 'spin_wheel_extra';

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

-- A client used to be allowed to create its own spin history row. Besides
-- forging dates, that made the old check-then-insert award RPC raceable.
drop policy if exists "Users can insert own spin records"
  on public.spin_wheel_history;
revoke insert, update, delete on public.spin_wheel_history
  from public, anon, authenticated;

-- Future dates can only have come from the former client-write policy and
-- would otherwise poison the daily guard indefinitely.
delete from public.spin_wheel_history where spin_date > current_date;

-- Preserve claims made through the older daily-spin RPC so deployment cannot
-- grant a second reward on the migration day.
insert into public.spin_wheel_history (
  user_id,
  spin_date,
  reward_amount,
  created_at
)
select
  player_id,
  created_at::date,
  max(amount)::integer,
  min(created_at)
from public.coin_transactions
where reason = 'daily_spin:server'
  and amount > 0
group by player_id, created_at::date
on conflict (user_id, spin_date) do nothing;

create or replace function public.award_spin_coins()
returns table (
  success boolean,
  reward_amount integer,
  message text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := current_date;
  v_spin_id uuid;
  v_reward integer;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
begin
  if v_user_id is null then
    return query select false, 0, 'Authenticated user required'::text;
    return;
  end if;

  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    return query select false, 0, 'Profile missing'::text;
    return;
  end if;

  v_reward := v_rewards[
    (
      (extract(day from v_today)::integer
        + extract(month from v_today)::integer * 31)
      % array_length(v_rewards, 1)
    ) + 1
  ];

  insert into public.spin_wheel_history (user_id, spin_date, reward_amount)
  values (v_user_id, v_today, v_reward)
  on conflict (user_id, spin_date) do nothing
  returning id into v_spin_id;

  if v_spin_id is null then
    return query select false, 0, 'Already spun today'::text;
    return;
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_user_id, v_reward, 'spin_wheel');

  return query select true, v_reward, 'Spin awarded successfully'::text;
end;
$$;

revoke all on function public.award_spin_coins() from public, anon;
grant execute on function public.award_spin_coins() to authenticated;

create or replace function public.claim_daily_spin()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_spin_id uuid;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
  v_reward integer;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  v_reward := v_rewards[1 + floor(random() * array_length(v_rewards, 1))::int];

  insert into public.spin_wheel_history (user_id, spin_date, reward_amount)
  values (v_player_id, current_date, v_reward)
  on conflict (user_id, spin_date) do nothing
  returning id into v_spin_id;

  if v_spin_id is null then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_reward, 'daily_spin:server');

  return jsonb_build_object(
    'amount', v_reward,
    'already_claimed', false
  );
end;
$$;

revoke all on function public.claim_daily_spin() from public, anon;
grant execute on function public.claim_daily_spin() to authenticated;

create or replace function public.can_spin_today()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and not exists (
      select 1
      from public.spin_wheel_history
      where user_id = auth.uid()
        and spin_date = current_date
    );
$$;

revoke all on function public.can_spin_today() from public, anon;
grant execute on function public.can_spin_today() to authenticated;

-- All reward RPCs use the same per-profile row lock. This turns each
-- check-and-insert pair into one serial operation for that player.
create or replace function public.claim_mission_reward(p_mission_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Görev ilerlemesi çevrimdışı cihazda tutulur; yalnız anahtar gönderen bir
  -- istemcinin görevi gerçekten yaptığını sunucu kanıtlayamaz. Eski istemci
  -- sözleşmesini bozmadan coin yazımını kapat. Yeni istemci görevi XP olarak
  -- gösterir.
  return jsonb_build_object(
    'amount', 0,
    'verification_required', true,
    'mission_key', p_mission_key
  );
end;
$$;

revoke all on function public.claim_mission_reward(text) from public, anon;
grant execute on function public.claim_mission_reward(text) to authenticated;

create or replace function public.claim_quiz_reward(
  p_room_id uuid default null,
  p_score integer default 0,
  p_correct_count integer default 0,
  p_best_streak integer default 0,
  p_total_questions integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_room_status text;
  v_room_score integer;
  v_correct_count integer;
  v_total_questions integer;
  v_answer_count integer;
  v_amount integer;
  v_reason text;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  if p_room_id is null then
    return jsonb_build_object(
      'amount', 0,
      'verification_required', true
    );
  end if;

  select r.status, greatest(coalesce(rp.score, 0), 0)
  into v_room_status, v_room_score
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id
   and rp.player_id = v_player_id
  where r.id = p_room_id;

  if not found then
    raise exception 'Player is not in the room';
  end if;
  if v_room_status <> 'finished' then
    return jsonb_build_object('amount', 0, 'room_not_finished', true);
  end if;

  select count(*)::integer into v_total_questions
  from public.room_questions
  where room_id = p_room_id;

  select
    count(*)::integer,
    count(*) filter (where pa.is_correct)::integer
  into v_answer_count, v_correct_count
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id
   and rq.question_id = pa.question_id
  where pa.room_id = p_room_id
    and pa.player_id = v_player_id;

  if v_total_questions < 1 or v_answer_count < v_total_questions then
    return jsonb_build_object('amount', 0, 'answers_incomplete', true);
  end if;

  v_reason := 'quiz_complete:room=' || p_room_id::text;
  if exists (
    select 1 from public.coin_transactions
    where player_id = v_player_id
      and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  v_amount :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_room_score / 80);

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_amount, v_reason);

  return jsonb_build_object(
    'amount', v_amount,
    'already_claimed', false
  );
end;
$$;

revoke all on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) from public, anon;
grant execute on function public.claim_quiz_reward(
  uuid, integer, integer, integer, integer
) to authenticated;

-- Doğru/puan sütunlarını yalnız submit_answer() yazabilir. Aksi halde oda
-- ödülündeki sunucu doğrulaması doğrudan tablo yazımıyla aşılabilirdi.
revoke insert, update, delete on public.player_answers
  from public, anon, authenticated;

-- Odayı yalnız sahibi ve son soru aşamasında bitirebilir. İstemci imzası
-- korunur; yalnız yetki ve durum sunucuda doğrulanır.
create or replace function public.finish_room_game(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text;
  v_index integer;
  v_question_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.status, r.current_question_index
  into v_status, v_index
  from public.rooms r
  where r.id = p_room_id
    and r.host_id = v_uid
  for update;

  if not found then
    raise exception 'Only the room host can finish the game';
  end if;
  select count(*)::integer into v_question_count
  from public.room_questions
  where room_id = p_room_id;
  if v_status = 'finished' then
    return json_build_object('status', 'finished');
  end if;
  if v_status <> 'active'
     or v_question_count < 1
     or coalesce(v_index, -1) < v_question_count - 1 then
    raise exception 'Room is not ready to finish';
  end if;

  update public.rooms
  set status = 'finished',
      finished_at = coalesce(finished_at, now())
  where id = p_room_id;
  return json_build_object('status', 'finished');
end;
$$;

revoke all on function public.finish_room_game(uuid) from public, anon;
grant execute on function public.finish_room_game(uuid) to authenticated;

create or replace function public.claim_tournament_reward()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tournament uuid;
  v_reason text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  select t.id into v_tournament
  from public.tournaments t
  where t.status = 'finished'
    and t.champion_id = v_uid
    and not exists (
      select 1
      from public.coin_transactions ct
      where ct.player_id = v_uid
        and ct.reason = 'tournament_champion:' || t.id::text
    )
  order by t.finished_at desc
  limit 1;

  if v_tournament is null then
    return jsonb_build_object('amount', 0, 'already_claimed', false);
  end if;

  v_reason := 'tournament_champion:' || v_tournament::text;
  if exists (
    select 1 from public.coin_transactions
    where player_id = v_uid and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, 200, v_reason);

  return jsonb_build_object('amount', 200, 'already_claimed', false);
end;
$$;

revoke all on function public.claim_tournament_reward() from public, anon;
grant execute on function public.claim_tournament_reward() to authenticated;

-- Remove values that could have been forged before the validation trigger.
-- Önce özgün değerleri erişimi kapalı bir karantinaya al; temizlik gerektiği
-- halde yanlış pozitif üretirse veri geri yüklenebilir.
create table if not exists public.profile_cosmetic_quarantine (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  avatar_url text,
  avatar_frame text,
  showcase_title text,
  quarantined_at timestamptz not null default now(),
  reason text not null
);
alter table public.profile_cosmetic_quarantine enable row level security;
revoke all on table public.profile_cosmetic_quarantine
  from public, anon, authenticated;

insert into public.profile_cosmetic_quarantine (
  profile_id,
  avatar_url,
  avatar_frame,
  showcase_title,
  reason
)
select
  p.id,
  p.avatar_url,
  p.avatar_frame,
  p.showcase_title,
  'release-integrity-validation'
from public.profiles p
where (
    p.avatar_url is not null
    and p.avatar_url !~ (
      '^https://hupivnxgjtsfafulzspo[.]supabase[.]co/storage/v1/object/public/avatars/'
      || p.id::text
      || '/avatar[.](jpg|png)([?]v=[0-9]+)?$'
    )
  )
  or (
    p.avatar_frame is not null
    and not (p.avatar_frame = any (array['bronze', 'silver', 'gold', 'mamoste']))
  )
  or (
    p.showcase_title is not null
    and p.showcase_title <> 'VIP'
    and p.showcase_title !~ '^(Xwendekar|Pispor|Mamoste) · (Ziman|Çand|Dîrok|Edebiyat|Wêje|Cografya|Erdnîgarî|Muzîk|Siyaset|Paradigma|Paradîgma|Sînema|Teknolojî)$'
  )
  or (
    p.showcase_title = 'VIP'
    and not exists (
      select 1
      from public.shop_purchases sp
      where sp.player_id = p.id
        and sp.item_id = 'profile_badge_vip'
    )
  )
on conflict (profile_id) do nothing;

update public.profiles
set avatar_url = null
where avatar_url is not null
  and avatar_url !~ (
    '^https://hupivnxgjtsfafulzspo[.]supabase[.]co/storage/v1/object/public/avatars/'
    || id::text
    || '/avatar[.](jpg|png)([?]v=[0-9]+)?$'
  );

update public.profiles
set avatar_frame = null
where avatar_frame is not null
  and not (avatar_frame = any (array['bronze', 'silver', 'gold', 'mamoste']));

update public.profiles p
set showcase_title = null
where showcase_title is not null
  and (
    (
      showcase_title = 'VIP'
      and not exists (
        select 1
        from public.shop_purchases sp
        where sp.player_id = p.id
          and sp.item_id = 'profile_badge_vip'
      )
    )
    or (
      showcase_title <> 'VIP'
      and showcase_title !~ '^(Xwendekar|Pispor|Mamoste) · (Ziman|Çand|Dîrok|Edebiyat|Wêje|Cografya|Erdnîgarî|Muzîk|Siyaset|Paradigma|Paradîgma|Sînema|Teknolojî)$'
    )
  );

create or replace function public.protect_paid_profile_cosmetics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_icon_changed boolean;
  v_color_changed boolean;
  v_url_changed boolean;
  v_frame_changed boolean;
  v_title_changed boolean;
begin
  if tg_op = 'INSERT' then
    v_icon_changed := true;
    v_color_changed := true;
    v_url_changed := true;
    v_frame_changed := true;
    v_title_changed := true;
  else
    v_icon_changed := new.avatar_icon is distinct from old.avatar_icon;
    v_color_changed := new.avatar_color is distinct from old.avatar_color;
    v_url_changed := new.avatar_url is distinct from old.avatar_url;
    v_frame_changed := new.avatar_frame is distinct from old.avatar_frame;
    v_title_changed := new.showcase_title is distinct from old.showcase_title;
  end if;

  if v_icon_changed
     and new.avatar_icon is not null
     and not (
       new.avatar_icon = any (array[
         'tembur', 'dengbej', 'ciya', 'roj', 'pirtuk', 'newroz', 'ster',
         'pen', 'cihan', 'mertal', 'tac', 'gul', 'dar', 'cav', 'birusk',
         'kupa'
       ])
     ) then
    raise exception 'Invalid avatar icon';
  end if;

  if v_color_changed
     and new.avatar_color is not null
     and new.avatar_color !~ '^#[0-9A-F]{6}$' then
    raise exception 'Invalid avatar color';
  end if;

  if v_url_changed
     and new.avatar_url is not null
     and new.avatar_url !~ (
       '^https://hupivnxgjtsfafulzspo[.]supabase[.]co/storage/v1/object/public/avatars/'
       || new.id::text
       || '/avatar[.](jpg|png)([?]v=[0-9]+)?$'
     ) then
    raise exception 'Avatar URL must point to the owner storage path';
  end if;

  if v_frame_changed
     and new.avatar_frame is not null
     and not (
       new.avatar_frame = any (array['bronze', 'silver', 'gold', 'mamoste'])
     ) then
    raise exception 'Invalid avatar frame';
  end if;

  if v_title_changed
     and new.showcase_title is not null
     and new.showcase_title <> 'VIP'
     and new.showcase_title !~ '^(Xwendekar|Pispor|Mamoste) · (Ziman|Çand|Dîrok|Edebiyat|Wêje|Cografya|Erdnîgarî|Muzîk|Siyaset|Paradigma|Paradîgma|Sînema|Teknolojî)$' then
    raise exception 'Invalid showcase title';
  end if;

  if new.showcase_title = 'VIP'
     and v_title_changed
     and not exists (
       select 1
       from public.shop_purchases sp
       where sp.player_id = new.id
         and sp.item_id = 'profile_badge_vip'
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

commit;
