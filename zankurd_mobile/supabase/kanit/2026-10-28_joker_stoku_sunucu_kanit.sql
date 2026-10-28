-- Kanıt: 2026-10-28_joker_stoku_sunucu.sql (begin…rollback içinde).
create temp table if not exists _kanit (n serial, line text);
do $$
declare
  a uuid; tx uuid; r int; s int;
begin
  select e.player_id into a from public.tournament_entries e
   where e.display_name = 'Test Ajan 4' order by e.joined_at desc limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  s := public.get_joker_stock();
  insert into pg_temp._kanit(line) values (format('KANIT %s 1 başlangıç stok %s', case when s >= 0 then 'OK' else 'HATA' end, s));
  -- Bir paket alınmış gibi (gerçek akış spend_coins; burada yalnız kayıt).
  insert into public.coin_transactions (player_id, amount, reason) values (a, -90, 'purchase_joker_pack_3') returning id into tx;
  insert into public.shop_purchases (player_id, item_id, price_paid, coin_transaction_id) values (a, 'joker_pack_3', 90, tx);
  r := public.get_joker_stock();
  insert into pg_temp._kanit(line) values (format('KANIT %s 2 paket sonrası %s', case when r = s + 3 then 'OK' else 'HATA' end, r));
  r := public.consume_joker_stock();
  insert into pg_temp._kanit(line) values (format('KANIT %s 3 kullanım kalan %s', case when r = s + 2 then 'OK' else 'HATA' end, r));
  perform public.consume_joker_stock(); perform public.consume_joker_stock();
  for i in 1..s loop perform public.consume_joker_stock(); end loop;
  r := public.consume_joker_stock();
  insert into pg_temp._kanit(line) values (format('KANIT %s 4 tükenince -1 (%s), stok %s', case when r = -1 and public.get_joker_stock() = 0 then 'OK' else 'HATA' end, r, public.get_joker_stock()));
  insert into pg_temp._kanit(line) values (format('KANIT %s 5 yetkiler', case when not has_table_privilege('authenticated','public.joker_stock_uses','select') and not has_function_privilege('anon','public.consume_joker_stock()','execute') and has_function_privilege('authenticated','public.consume_joker_stock()','execute') then 'OK' else 'HATA' end));
  perform set_config('request.jwt.claims', '{}', true);
end $$;
select line from pg_temp._kanit order by n;
