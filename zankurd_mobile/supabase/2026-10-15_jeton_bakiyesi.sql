-- 2026-10-15: JETON BAKİYESİ sunucuda toplansın.
--
-- NİÇİN: İstemci bakiyeyi `coin_transactions`ın bütün satırlarını çekip Dart'ta
-- toplayarak buluyordu. PostgREST tek yanıtta en fazla 1000 satır döndürür
-- (max_rows); işlem sayısı 1000'i geçen aktif oyuncunun bakiyesi sessizce
-- EKSİK görünür (en yeni 1000 satırın toplamı), mağaza "yetersiz jeton" der ve
-- ağ da her açılışta bütün defteri indirir. Hiçbir hata atılmadığı için fark
-- edilmiyordu: sınama hesaplarında 1000'den az satır vardı.
--
-- NE YAPAR: `get_my_coin_balance()` çağıranın (auth.uid()) bütün işlem
-- tutarlarını sunucuda toplayıp tek tamsayı döndürür. spend_coins ile aynı
-- biçimde SECURITY DEFINER + search_path=public; yalnız authenticated çağırır
-- (canlı spend_coins ACL'i: postgres, authenticated, service_role).
-- İstemci RPC yokken (PGRST202) eski satır toplamına düşer.
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-10-15_jeton_bakiyesi.sql`
-- Geri alma: `drop function public.get_my_coin_balance();`

begin;

create or replace function public.get_my_coin_balance()
returns integer
language sql
stable
security definer
set search_path = public
as $function$
  select coalesce(sum(amount), 0)::integer
  from public.coin_transactions
  where player_id = auth.uid();
$function$;

revoke all on function public.get_my_coin_balance() from public, anon;
grant execute on function public.get_my_coin_balance() to authenticated;

commit;
