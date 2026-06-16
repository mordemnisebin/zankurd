-- Oyuncunun coin bakiyesini kontrol eder; yeterliyse negatif işlem yazar.
create or replace function public.spend_coins(p_amount integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid    := auth.uid();
  v_balance integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  select coalesce(sum(amount), 0) into v_balance
  from coin_transactions
  where player_id = v_uid;

  if v_balance < p_amount then
    return jsonb_build_object('success', false, 'balance', v_balance);
  end if;

  insert into coin_transactions (player_id, amount, reason)
  values (v_uid, -p_amount, p_reason);

  return jsonb_build_object('success', true, 'balance', v_balance - p_amount);
end;
$$;
