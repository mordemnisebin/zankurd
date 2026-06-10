create or replace function public.claim_daily_spin()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_existing_id uuid;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
  v_reward integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select id
    into v_existing_id
  from public.coin_transactions
  where player_id = v_player_id
    and reason like 'daily_spin:%'
    and created_at >= date_trunc('day', now())
    and created_at < date_trunc('day', now()) + interval '1 day'
  limit 1;

  if v_existing_id is not null then
    return jsonb_build_object(
      'amount', 0,
      'already_claimed', true
    );
  end if;

  v_reward := v_rewards[1 + floor(random() * array_length(v_rewards, 1))::int];

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_reward, 'daily_spin:server');

  return jsonb_build_object(
    'amount', v_reward,
    'already_claimed', false
  );
end;
$$;

revoke all on function public.claim_daily_spin() from public;
grant execute on function public.claim_daily_spin() to authenticated;
