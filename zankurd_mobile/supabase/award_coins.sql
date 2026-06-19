-- Oyuncunun coin bakiyesine pozitif işlem ekler (görev ödülleri için).
create or replace function public.award_coins(p_amount integer, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  if p_amount <= 0 then return; end if;

  insert into coin_transactions (player_id, amount, reason)
  values (v_uid, p_amount, p_reason);
end;
$$;
