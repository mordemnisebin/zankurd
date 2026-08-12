-- 2026-07-23: shop_items tablosu Dart kaynağıyla (shop_screen.dart _items)
-- senkron değildi. Canlı browser doğrulamasında görüldü: mağaza ekranı
-- şık kartlarını Supabase'ten (theme_color dahil) çekiyor ve bu satır varsa
-- Dart'taki statik yedek rengi HER ZAMAN eziyor (bkz. shop_screen.dart:270-308
-- `_dynamicItems = dynamicItems`). 2026-07-13 tarihli ilk seed
-- (2026-07-13_shop_chat_suggestions.sql) hiçbir zaman Dart'taki marka
-- paletiyle eşleşmemiş (ör. joker_bundle SQL'de 'FF3B81' iken Dart'ta hep
-- accent/#F5931E olmuştu) — iki kaynak baştan beri ayrı ilerlemiş.
--
-- Bu dosya 13 ürünü de (10'u zaten vardı + emoji_roj/emoji_ster/frame_simple
-- eksikti) şu anki Dart _items listesiyle birebir eşleşecek şekilde upsert
-- eder — başlık, açıklama, fiyat, ikon, renk. M24 (2026-07-23) paletindeki
-- 3 değişiklik dahil: avatar_frame_neon, joker_pack_3, profile_badge_vip.
--
-- Çalıştırma: Supabase SQL Editor'de bu dosyayı olduğu gibi yapıştırıp çalıştır.
--
-- ⚠ FİYATLAR AÇISINDAN AŞILDI — bkz. `2026-08-12_shop_price_anchor.sql`.
--
-- "Tekrar çalıştırmak güvenli" cümlesi yalnız ŞEMA için doğruydu. Upsert dört
-- ürünü ESKİ fiyatlarıyla (200/600/750/1000) yeniden yazıyordu; çıpa göçünden
-- sonra yeniden koşulunca fiyatlar SESSİZCE eskiye dönüyordu — hiçbir uyarı
-- çıkmadan. 2026-08-12'de yerelde ölçüldü: 120/480 tek komutla 200/750 oldu.
--
-- İlk çözüm dosyayı tümden durduran bir blok koymaktı; o blok yanlıştı,
-- çünkü bu dosyanın işi yalnız katalog değil ve durdurma diğer işleri de
-- engelliyordu. Doğru çözüm aşağıda: `cost` çakışmada güncellenmiyor.
INSERT INTO shop_items (id, title_ku, title_tr, desc_ku, desc_tr, cost, icon_name, theme_color)
VALUES
  ('emoji_roj', 'Emojî Roj', 'Güneş Emojisi',
   'Emojîya rojê ya zêrîn ji bo profîla te.',
   'Profilin için altın renkli güneş emojisi.',
   10, 'sun_regular', 'E7B53C'),
  ('emoji_ster', 'Emojî Stêr', 'Yıldız Emojisi',
   'Emojîya stêrkê ya mor ji bo profîla te.',
   'Profilin için mor renkli yıldız emojisi.',
   10, 'star_regular', '7052A3'),
  ('frame_simple', 'Çarçoveya Hêsan', 'Basit Çerçeve',
   'Çarçoveyeke hêsan a cyan ji bo avatarê te.',
   'Avatarın için basit cyan renkli çerçeve.',
   20, 'image_regular', '288077'),
  ('joker_bundle', 'Paketa Jokeran', 'Joker Paketi',
   'Hemû joker ji bo pêşbirka bê têne nûkirin.',
   'Bir sonraki yarışma için tüm joker haklarını sıfırlar.',
   500, 'auto_awesome_motion_outlined', 'F5931E'),
  ('extra_lifeline', 'Cana Zêde', 'Ekstra Can',
   'Di dema quizê de canekî din dide te.',
   'Yarışma esnasında elendiğinde kullanabileceğin 1 can verir.',
   100, 'favorite_border_rounded', 'F5931E'),
  ('spin_wheel_extra', 'Zivirîna Zêde', 'Ekstra Çevirme',
   'Ji bo çerxa rojane mafekî zivirînê yê nû dide.',
   'Bugün çarkı tekrar çevirebilmek için ekstra bir hak tanımlar.',
   200, 'casino_outlined', '3DA968'),
  ('premium_colors', 'Rengên Taybet', 'Premium Renkler',
   'Ji bo profilê rengên nû û taybet vedike.',
   'Profil kartı ve avatarı için özel premium renk paletleri açar.',
   300, 'palette_outlined', 'E7B53C'),
  ('avatar_frame_gold', 'Çarçoveya Zêrîn', 'Altın Çerçeve',
   'Ji bo avatarê te çarçoveyeke zêrîn a taybet.',
   'Avatarın için özel altın çerçeve.',
   750, 'star_rounded', 'E7B53C'),
  ('avatar_frame_neon', 'Çarçoveya Neon', 'Neon Çerçeve',
   'Avatarê te bi rengên neon ên geş dibiriqe.',
   'Avatarın neon renklerle parıldasın.',
   600, 'auto_awesome_rounded', 'F5931E'),
  ('name_color_gold', 'Navê Zêrîn', 'Altın İsim',
   'Navê te di profîl û rêzbendiyê de bi rengê zêrîn xuya dibe.',
   'İsmin profil ve liderlik tablosunda altın renginde görünsün.',
   500, 'text_fields_rounded', 'E7B53C'),
  ('name_color_purple', 'Navê Mor', 'Mor İsim',
   'Navê te bi rengekî mor ê taybet were xuyakirin.',
   'İsmin özel mor renkte görünsün.',
   400, 'text_format_rounded', '7052A3'),
  ('joker_pack_3', 'Pakêta Jokeran (3)', 'Joker Paketi (3)',
   'Ji bo pêşbirka bê 3 jokerên zêde: 50/50, temaşevan û bersiva ducar.',
   'Bir sonraki yarışma için 3 ekstra joker: 50/50, seyirci ve çift cevap.',
   350, 'auto_fix_high_rounded', '3DA968'),
  ('profile_badge_vip', 'Rozeta VIP', 'VIP Rozeti',
   'Profîla te de rozeteke taybet a VIP xuya dibe.',
   'Profilinde özel VIP rozeti görünsün.',
   1000, 'diamond_rounded', 'E7B53C')
-- ⚠ FİYAT SÜTUNU BU DOSYANIN İŞİ DEĞİL — bkz.
-- `2026-08-12_shop_price_anchor.sql`.
--
-- Bu dosya katalog METNİNİ Dart listesiyle eşitler: başlık, açıklama,
-- ikon, renk. Fiyat başka bir yerde, ölçülerek belirleniyor.
--
-- Çakışmada `cost` bilerek GÜNCELLENMİYOR. Eskiden güncelleniyordu ve
-- bedeli sessizdi: çıpa uygulandıktan sonra bu dosyayı yeniden koşmak
-- fiyatları eski değerlerine döndürüyor, üstelik hiçbir uyarı vermiyordu
-- (2026-08-12'de yerelde ölçüldü — 120/480 tek komutla 200/750 oldu).
--
-- İlk INSERT'te `cost` yine yazılır; sıfırdan kurulan bir zincirde
-- katalog fiyatsız kalmaz, çıpa göçü sonradan kendi değerini koyar.
ON CONFLICT (id) DO UPDATE SET
  title_ku = EXCLUDED.title_ku,
  title_tr = EXCLUDED.title_tr,
  desc_ku = EXCLUDED.desc_ku,
  desc_tr = EXCLUDED.desc_tr,
  icon_name = EXCLUDED.icon_name,
  theme_color = EXCLUDED.theme_color;
