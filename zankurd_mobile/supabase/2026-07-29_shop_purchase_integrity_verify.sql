-- Salt okunur canlı doğrulama. Forward göçten sonra bütün bool alanlar true,
-- bütün *_rows alanları 0 olmalıdır (quarantine_rows bilgi amaçlıdır).
select
  to_regclass('public.shop_purchases') is not null as purchases_table_ok,
  to_regclass('public.profile_cosmetic_quarantine') is not null
    as quarantine_table_ok,
  has_table_privilege('authenticated', 'public.shop_purchases', 'SELECT')
    as purchases_owner_read_ok,
  not has_table_privilege(
    'authenticated', 'public.shop_purchases', 'INSERT,UPDATE,DELETE'
  ) as purchases_client_write_closed,
  not has_table_privilege(
    'authenticated', 'public.coin_transactions', 'INSERT,UPDATE,DELETE'
  ) as coin_client_write_closed,
  not has_table_privilege(
    'authenticated', 'public.player_answers', 'INSERT,UPDATE,DELETE'
  ) as answer_client_write_closed,
  has_function_privilege(
    'authenticated', 'public.spend_coins(integer,text)', 'EXECUTE'
  ) as spend_rpc_ok,
  has_function_privilege(
    'authenticated',
    'public.claim_quiz_reward(uuid,integer,integer,integer,integer)',
    'EXECUTE'
  ) as quiz_rpc_ok,
  pg_get_functiondef(
    'public.claim_mission_reward(text)'::regprocedure
  ) like '%verification_required%' as mission_no_forged_coin_ok,
  pg_get_functiondef(
    'public.claim_quiz_reward(uuid,integer,integer,integer,integer)'::regprocedure
  ) like '%from public.player_answers%' as quiz_server_answers_ok,
  (select count(*) from public.spin_wheel_history
   where spin_date > current_date) as future_spin_rows,
  (select count(*)
   from public.shop_purchases sp
   left join public.coin_transactions ct on ct.id = sp.coin_transaction_id
   where ct.id is null or ct.player_id <> sp.player_id or ct.amount >= 0)
    as invalid_purchase_rows,
  (select count(*)
   from public.profiles p
   where p.showcase_title = 'VIP'
     and not exists (
       select 1 from public.shop_purchases sp
       where sp.player_id = p.id and sp.item_id = 'profile_badge_vip'
     )) as forged_vip_rows,
  (select count(*) from public.profile_cosmetic_quarantine)
    as quarantine_rows;
