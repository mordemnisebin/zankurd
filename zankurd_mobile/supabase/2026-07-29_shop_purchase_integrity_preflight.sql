-- Salt okunur canlı uyumluluk kontrolü. Forward göçten hemen önce çalıştır.
select
  (select format_type(a.atttypid, a.atttypmod)
   from pg_attribute a
   where a.attrelid = 'public.profiles'::regclass
     and a.attname = 'id' and not a.attisdropped) as profile_id_type,
  (select format_type(a.atttypid, a.atttypmod)
   from pg_attribute a
   where a.attrelid = 'public.shop_items'::regclass
     and a.attname = 'id' and not a.attisdropped) as shop_item_id_type,
  (select format_type(a.atttypid, a.atttypmod)
   from pg_attribute a
   where a.attrelid = 'public.shop_items'::regclass
     and a.attname = 'cost' and not a.attisdropped) as shop_cost_type,
  (select format_type(a.atttypid, a.atttypmod)
   from pg_attribute a
   where a.attrelid = 'public.coin_transactions'::regclass
     and a.attname = 'id' and not a.attisdropped) as coin_id_type,
  (select format_type(a.atttypid, a.atttypmod)
   from pg_attribute a
   where a.attrelid = 'public.coin_transactions'::regclass
     and a.attname = 'player_id' and not a.attisdropped) as coin_player_type,
  (select format_type(a.atttypid, a.atttypmod)
   from pg_attribute a
   where a.attrelid = 'public.spin_wheel_history'::regclass
     and a.attname = 'id' and not a.attisdropped) as spin_id_type,
  to_regclass('public.shop_purchases')::text as existing_shop_purchases,
  (select count(*) from public.spin_wheel_history
   where spin_date > current_date) as future_spin_rows;
