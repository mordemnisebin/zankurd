-- 2026-09-28: uygulamada gizli kategoriler sunucu seçimlerinde de kapalı.
--
-- Neden: istemci Paradigma, Siyaset ve Teknolojî'yi
-- (lib/src/config/category_visibility.dart `hiddenCategoryIds`) listelerde
-- ve oda kurma ekranında göstermiyor. Ama hızlı düellonun "Rastgele" kuyruğu
-- (`join_matchmaking`) gerçek kategoriyi sunucuda, ETKİN kategoriler
-- arasından rastgele seçiyor. Seçim gizli bir kategoriye düşerse iki oyuncu
-- uygulamada hiç göremedikleri bir kategoride eşleşiyordu. Oda kurma
-- (`create_online_room`) ve eşleşme yalnız `is_active = true` kategoriyi
-- kabul ettiği için kategoriyi devre dışı bırakmak bütün oda yollarını
-- kapatır; soru onaylarına (`is_approved`) dokunmak gerekmez.
--
-- İstemci tarafı: oda soruları artık istemcide atılmıyor (bkz.
-- test/room_questions_alignment_test.dart). Bu göç uygulanana dek gizli bir
-- kategoriye düşen oda yine oynanır — yalnız o kategorinin sorularıyla.
--
-- Etkisi: `categories` okuma politikaları yalnız etkin satırı gösterir; bu
-- kategoriler istemciye görünmez olur (uygulama kategori listesini yerel
-- bankadan okuyor, sunucudan değil). Sunucuda bu adla bir kategori yoksa
-- (ör. Teknolojî) satır güncellenmez; göç tekrar çalıştırılabilir.
--
-- Geri alma (kitle büyüyüp kategoriler açılınca, istemci listesiyle
-- birlikte):
--   update public.categories set is_active = true
--   where name in ('Paradigma', 'Siyaset', 'Teknolojî');
--
-- Postflight:
--   select name, is_active from public.categories order by name;

begin;

update public.categories
set is_active = false
where name in ('Paradigma', 'Siyaset', 'Teknolojî')
  and is_active = true;

commit;
