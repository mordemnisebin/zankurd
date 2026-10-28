-- Joker paketi hakları hesapta tutulur (2026-10-28).
--
-- Kusur: "Joker paketi (3)" jetonla SUNUCUDA ödeniyor (`spend_coins`,
-- `shop_purchases.item_id = 'joker_pack_3'`) ama kalan hak yalnız cihazda
-- (SharedPreferences) tutuluyordu. Uygulama silinir ya da telefon
-- değişirse parası ödenmiş haklar kayboluyordu (gece kod denetimi:
-- GPT-6 Sol).
--
-- Düzeltme: kullanılan hak sunucuda kayıt tutulur; kalan hak =
-- alınan paket × 3 − kullanılan. İstemci açılışta okur, kullanımda düşer.
-- `spend_coins` değişmez; satın alma kaydı zaten `shop_purchases`ta.
-- Geçmiş aktarımı gerekmez: uygulandığı an canlıda hiç joker paketi
-- satın alımı yoktu (`shop_purchases` joker_pack_3 = 0; ürün 2026-10-27'de
-- eklendi, yayına çıkmadı). GPT-6 Sol incelemesi: kilit profil satırına
-- değil kullanıcıya (advisory) bağlandı.
--
-- GERİ ALMA: drop function consume_joker_stock(), get_joker_stock();
-- drop table joker_stock_uses.
begin;

create table if not exists public.joker_stock_uses (
  id bigint generated always as identity primary key,
  player_id uuid not null references auth.users(id) on delete cascade,
  used_at timestamptz not null default now()
);

create index if not exists joker_stock_uses_player_idx
  on public.joker_stock_uses (player_id);

alter table public.joker_stock_uses enable row level security;
revoke all on public.joker_stock_uses from public, anon, authenticated;

create or replace function public.get_joker_stock()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_bought integer;
  v_used integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  select count(*)::integer * 3 into v_bought
  from public.shop_purchases
  where player_id = v_uid and item_id = 'joker_pack_3';
  select count(*)::integer into v_used
  from public.joker_stock_uses
  where player_id = v_uid;
  return greatest(v_bought - v_used, 0);
end;
$$;

-- Bir hak düşer; kalan hak yoksa düşmez. Dönüş: düşüşten SONRA kalan hak,
-- düşülemediyse -1. Profil satırı kilitlenir: aynı anda iki kullanım tek
-- hakkı iki kez düşmesin.
create or replace function public.consume_joker_stock()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_left integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  -- Kullanıcı başına işlem kilidi: profil satırı olmasa bile aynı anda iki
  -- kullanım tek hakkı iki kez düşemez.
  perform pg_advisory_xact_lock(hashtext('joker_stock:' || v_uid::text));
  v_left := public.get_joker_stock();
  if v_left <= 0 then
    return -1;
  end if;
  insert into public.joker_stock_uses (player_id) values (v_uid);
  return v_left - 1;
end;
$$;

revoke execute on function public.get_joker_stock() from public, anon;
revoke execute on function public.consume_joker_stock() from public, anon;
grant execute on function public.get_joker_stock() to authenticated;
grant execute on function public.consume_joker_stock() to authenticated;

commit;
