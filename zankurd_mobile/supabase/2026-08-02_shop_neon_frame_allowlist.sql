-- ZanKurd — mağaza izin listesine `avatar_frame_neon` eklenmesi
--
-- SORUN (2026-08-02 denetimi, A-01 -> P1-006)
--
-- `shop_items` tablosunda `avatar_frame_neon` 600 coin fiyatıyla mevcut
-- (2026-07-13_shop_chat_suggestions.sql ve 2026-07-23_shop_items_sync.sql)
-- ve istemci kataloğu onu listeliyor (`shop_screen.dart`). Ancak
-- 2026-07-29_shop_purchase_integrity_fix.sql ile gelen `spend_coins`
-- izin listesi yalnız üç ürünü tanıyor:
--
--     'spin_wheel_extra', 'avatar_frame_gold', 'profile_badge_vip'
--
-- Dolayısıyla `purchase_avatar_frame_neon` çağrısı
-- {'success': false, 'error': 'product not available'} ile reddediliyordu.
-- İstemci `spendCoins` bu hata dizesini atıp yalnız `false` döndürdüğü için
-- kullanıcı gerekçesiz bir "satın alma başarısız" görüyordu — ve 600 coin
-- biriktirmiş olsa bile ürünü ASLA alamıyordu.
--
-- İronik olan: istemci tarafı 2026-07-31'de zaten düzeltilmişti.
-- `AvatarFrame.neon` enum'a eklendi, rengi ve etiketi tanımlandı,
-- `avatar_editor_screen` çerçeveyi `hasPurchased('avatar_frame_neon')` ile
-- açıyor. Ama `hasPurchased` hiçbir zaman true olamıyordu, çünkü satın alma
-- sunucuda tamamlanamıyordu. Eksik olan tek şey bu izin listesiydi.
--
-- BU GÖÇ NE YAPAR
--
-- `spend_coins`i yalnız izin listesi genişletilmiş hâliyle yeniden tanımlar.
-- Gövdenin geri kalanı 2026-07-29_shop_purchase_integrity_fix.sql ile
-- BİREBİR aynıdır: fiyat sunucudan (`shop_items.cost`) okunur, istemcinin
-- gönderdiği tutarla eşleşmesi zorunludur, profil satırı kilitlenir,
-- tekrar satın alma engellenir (spin_wheel_extra hariç), bakiye kontrol
-- edilir ve harcama ile satın alma kaydı tek transaction'da yazılır.
--
-- Yeniden çalıştırmak güvenlidir (`create or replace`).
--
-- UYGULAMA: Supabase SQL Editor veya CLI. Uygulandıktan sonra
-- `supabase/applied.md` dosyasına satır eklenmelidir.

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
  v_transaction_id uuid;
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
    if not (
      v_item_id = any (array[
        'spin_wheel_extra',
        'avatar_frame_gold',
        'avatar_frame_neon',   -- 2026-08-02: eksikti; ürün alınamıyordu
        'profile_badge_vip'
      ])
    ) then
      return jsonb_build_object(
        'success', false,
        'error', 'product not available'
      );
    end if;
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
       from public.shop_purchases
       where player_id = v_uid
         and item_id = v_item_id
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
  values (v_uid, -v_expected, p_reason)
  returning id into v_transaction_id;

  if v_item_id is not null then
    insert into public.shop_purchases (
      player_id,
      item_id,
      price_paid,
      coin_transaction_id
    ) values (
      v_uid,
      v_item_id,
      v_expected,
      v_transaction_id
    );
  end if;
  return jsonb_build_object(
    'success', true,
    'balance', v_balance - v_expected
  );
end;
$$;

revoke all on function public.spend_coins(integer, text) from public, anon;
grant execute on function public.spend_coins(integer, text) to authenticated;

-- ── Uygulama sonrası doğrulama (elle çalıştırılır) ───────────────────────
--
-- 1) İzin listesi dört ürünü de tanıyor mu?
--
-- select p.proname,
--        pg_get_functiondef(p.oid) like '%avatar_frame_neon%' as neon_allowed
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'spend_coins';
--
--    beklenen: neon_allowed = true
--
-- 2) Katalogdaki her ürünün sunucuda fiyatı var mı?
--
-- select id, cost
-- from public.shop_items
-- where id in ('spin_wheel_extra', 'avatar_frame_gold',
--              'avatar_frame_neon', 'profile_badge_vip')
-- order by id;
--
--    beklenen: 4 satır, hepsinde cost > 0
