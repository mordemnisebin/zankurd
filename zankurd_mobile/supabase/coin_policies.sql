-- coin_transactions: istemciden yazma tamamen kapalıdır.
-- Tüm coin yazımları security definer RPC'ler üzerinden yapılır
-- (claim_quiz_reward, claim_daily_spin). İstemci yalnızca kendi
-- işlemlerini okuyabilir.

drop policy if exists "Users read their own coin transactions" on public.coin_transactions;
drop policy if exists "Users insert their own coin transactions" on public.coin_transactions;
drop policy if exists "Users insert their own non-spin coin transactions" on public.coin_transactions;

create policy "Users read their own coin transactions"
  on public.coin_transactions for select
  to authenticated
  using (player_id = auth.uid());
