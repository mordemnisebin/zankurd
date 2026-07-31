-- Odada bir oyuncunun durumu değişince diğerleri görmüyordu.
--
-- ## Belirti
--
-- Android ev sahibi ile iOS katılan arasında canlı denemede:
--
--   * Katılan odaya girince ev sahibinin listesi 1 → 2 oldu (INSERT geldi).
--   * Katılan "hazır" olunca ev sahibinde hâlâ "Li bendê" yazıyordu ve
--     dakikalarca öyle kaldı (UPDATE gelmedi).
--
-- Oda ekranı tam da bunu vaat ediyor: "Rewşa te di odê de rasterast ji
-- lîstikvanên din re tê nîşandan." Vaat tutulmuyordu.
--
-- 2026-08-01'de bulundu.
--
-- ## Sebep
--
-- `add_realtime_room_tables.sql` `rooms` ve `room_players` tablolarını
-- `supabase_realtime` publication'ına ekledi ve şu notu düştü:
--
--   "Realtime, mevcut SELECT policy'lerini kullanarak erişim kontrolü
--    yapar."
--
-- Doğru — ama eksik. RLS açık bir tabloda Realtime, UPDATE olayını
-- aboneye iletmeden önce satırı yetkilendirmek zorunda ve bunun için
-- WAL'daki ESKİ satıra bakar. PostgreSQL varsayılanı
-- `REPLICA IDENTITY DEFAULT`tur: WAL'a yalnız birincil anahtar kolonları
-- yazılır. Yetkilendirme eksik satırla yapılamayınca olay sessizce
-- düşürülür.
--
-- INSERT'in geçmesi tam da bu yüzden: onun eski satırı yok, dolayısıyla
-- eksik de olamaz. Kusurun "realtime hiç çalışmıyor" gibi değil "bazen
-- çalışıyor" gibi görünmesinin sebebi buydu.
--
-- ## Düzeltme
--
-- `REPLICA IDENTITY FULL`: güncellemede eski satırın tamamı WAL'a yazılır,
-- Realtime yetkilendirmeyi yapabilir ve olay aboneye ulaşır.
--
-- Maliyet, güncelleme başına WAL hacminin artmasıdır. Bu iki tablo için
-- önemsiz: satırlar dar (oda kaydı ve oyuncu üyeliği), güncellemeler
-- seyrek ve satırlar oda bitince temizleniyor
-- (`2026-07-21_room_cleanup.sql`).
--
-- `room_messages` bilerek DIŞARIDA: sohbet mesajı yalnız eklenir, hiç
-- güncellenmez; tam eski satırı loglamanın karşılığı yok.

begin;

alter table public.rooms replica identity full;
alter table public.room_players replica identity full;

-- Publication üyeliğini de tazele: tablo eklenmemişse hiçbir olay
-- doğmaz ve yukarıdaki ayar tek başına bir şey değiştirmez. İdempotent.
do $$
begin
  alter publication supabase_realtime add table public.rooms;
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_players;
exception
  when duplicate_object then null;
end
$$;

commit;
