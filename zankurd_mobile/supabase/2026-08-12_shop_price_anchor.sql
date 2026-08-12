-- Mağaza fiyatlarını ölçülen gelire çıpalar ve tabanı kalıcı kılar.
--
-- ## Niçin
--
-- Vitrin fiyatı `public.shop_items` tablosundan gelir ve `spend_coins`
-- istemcinin gönderdiği tutarın `shop_items.cost` ile BİREBİR eşit olmasını
-- şart koşar (`2026-08-02_shop_neon_frame_allowlist.sql`). Yani tablo tek
-- yetkili kaynaktır: hem gösterilen hem kabul edilen fiyat odur.
--
-- Fiyatlar ölçülerek belirlendi, sezgiyle değil. Çevrimdışı oynayan bir
-- oyuncunun tek jeton kaynağı günlük çark: [10,25,50,15,75,20,100,30] →
-- günde ortalama 40,6 jeton. Eski fiyatlarla ilk satın alma 4,9 gün, katalogun
-- tamamı 24,6 gün sürüyordu; yeni oyuncu mağazaya girip hiçbir şey alamıyor ve
-- yakın bir hedef de göremiyordu. Yeni tempo: ilk satın alma 3,0 gün, katalog
-- 17,7 gün.
--
--   spin_wheel_extra   200 → 120
--   avatar_frame_neon  600 → 350
--   avatar_frame_gold  750 → 480
--   profile_badge_vip 1000 → 720
--
-- ## Niçin yalnız `cost`
--
-- Bu göçün ilk taslağı bütün satırı `insert … on conflict do update` ile
-- yeniden yazıyordu: başlık, açıklama, ikon ve renk dahil. Fiyat değiştirmek
-- için gereken bu değildi ve bedeli görünmezdi — yayındaki uygulama bu
-- alanları tablodan okuduğu için, farkında olmadan yazılan bir başlık ya da
-- renk üretimde anında görünürdü. Göç artık yalnız değiştirmeye geldiği
-- alana dokunuyor.
--
-- ## Niçin kısıt
--
-- Taban denetimi de bir `do` bloğuydu: yalnız bu göç koştuğu AN doğruydu.
-- Oysa iki eski göç (`2026-07-13_shop_chat_suggestions.sql`,
-- `2026-07-23_shop_items_sync.sql`) aynı birincil anahtarları eski
-- fiyatlarla upsert ediyor ve ikisi de "yeniden çalıştırma güvenli" diyor.
-- Biri yarın yeniden koşarsa çıpa sessizce geri alınırdı. Kısıt bunu
-- gürültüyle durdurur: eski göç artık sessizce başarmaz, hata verir.
--
-- Kısıtın koruduğu değişmez şudur: `spin_wheel_extra` bir ÇARK HAKKI satar
-- ve çarkın azami ödülü 100'dür. Fiyat 100'ün altına inerse "satın al →
-- çevir → kâr et" döngüsü sınırsız jeton pompasına döner.
--
-- Yeniden çalıştırma güvenlidir.

begin;

-- Kısıt önce gelir: bundan sonraki her yazım — bu göçünki dahil — onun
-- altından geçer.
alter table public.shop_items
  drop constraint if exists shop_items_spin_wheel_above_wheel_max;

alter table public.shop_items
  add constraint shop_items_spin_wheel_above_wheel_max
  check (id <> 'spin_wheel_extra' or cost > 100);

update public.shop_items set cost = 120 where id = 'spin_wheel_extra';
update public.shop_items set cost = 350 where id = 'avatar_frame_neon';
update public.shop_items set cost = 480 where id = 'avatar_frame_gold';
update public.shop_items set cost = 720 where id = 'profile_badge_vip';

-- Sessiz eksik yok: dört ürünün dördü de tabloda bulunmalı. Biri yoksa
-- vitrinde hiç görünmüyor demektir ve bunu fiyat göçü değil, ayrı bir
-- inceleme çözer.
do $$
declare
  v_found integer;
begin
  select count(*) into v_found
  from public.shop_items
  where (id, cost) in (
    ('spin_wheel_extra', 120),
    ('avatar_frame_neon', 350),
    ('avatar_frame_gold', 480),
    ('profile_badge_vip', 720)
  );

  if v_found <> 4 then
    raise exception
      'Fiyat çıpası eksik uygulandı: beklenen 4 ürün, bulunan %. '
      'Eksik id vitrinde hiç görünmüyor olabilir.', v_found;
  end if;
end $$;

commit;
