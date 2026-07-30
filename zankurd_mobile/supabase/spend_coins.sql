-- Legacy bootstrap copy. The forward migration
-- 2026-07-29_shop_purchase_integrity_fix.sql is authoritative for live use.
-- Bu dosya yeni shop_purchases defteri kurulduktan sonra tek başına yeniden
-- uygulanmamalıdır; hak kaydı yazmayan eski sözleşmeye dönmek olur.
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
