-- Legacy daily-spin entry point. It shares the same unique history row as
-- award_spin_coins, so the two RPCs cannot both pay the same player/day.

create table if not exists public.spin_wheel_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  spin_date date not null,
  reward_amount integer not null,
  created_at timestamptz not null default now(),
  unique (user_id, spin_date)
);

alter table public.spin_wheel_history enable row level security;
drop policy if exists "Users can insert own spin records"
  on public.spin_wheel_history;
revoke insert, update, delete on public.spin_wheel_history
  from public, anon, authenticated;

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
