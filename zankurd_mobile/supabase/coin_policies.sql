drop policy if exists "Users read their own coin transactions" on public.coin_transactions;
drop policy if exists "Users insert their own coin transactions" on public.coin_transactions;

create policy "Users read their own coin transactions"
  on public.coin_transactions for select
  to authenticated
  using (player_id = auth.uid());

create policy "Users insert their own coin transactions"
  on public.coin_transactions for insert
  to authenticated
  with check (player_id = auth.uid());
