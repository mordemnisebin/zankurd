-- Daily spin backend. Safe to rerun: no table drop and no client write path.

create table if not exists public.spin_wheel_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  spin_date date not null,
  reward_amount integer not null,
  created_at timestamptz not null default now(),
  unique (user_id, spin_date)
);

alter table public.spin_wheel_history enable row level security;

drop policy if exists "Users can view own spin history"
  on public.spin_wheel_history;
create policy "Users can view own spin history"
  on public.spin_wheel_history for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own spin records"
  on public.spin_wheel_history;
revoke insert, update, delete on public.spin_wheel_history
  from public, anon, authenticated;

create index if not exists idx_spin_wheel_user_date
  on public.spin_wheel_history(user_id, spin_date desc);

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
