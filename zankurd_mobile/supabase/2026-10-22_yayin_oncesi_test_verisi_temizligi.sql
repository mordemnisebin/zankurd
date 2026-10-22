-- Yayın öncesi test verisi temizliği (2.1.0, 2026-10-22).
--
-- Niçin: uygulama mağazalarda ilk kez herkese duyurulacak. Canlı veritabanında
-- yalnız sahibin ve ajanların test hesapları var (bkz. memory
-- canli-veri-sahibin-testi: 2026-10-15'e dek kimseyle paylaşılmadı). İlk gerçek
-- kullanıcı sıralamada, aramada ve odalarda test adlarını görmesin.
--
-- Silinen: bütün hesaplar (auth.users) ve onlara bağlı her şey (profil, puan,
-- cevaplar, jeton hareketleri, odalar, düellolar, arkadaşlıklar, sohbet,
-- bildirim kuyruğu, lig üyelikleri, analitik), lig haftaları, soru önerileri
-- ve test bildirimleri.
-- Dokunulmayan: sorular, kategoriler, dersler, mağaza ürünleri, turnuva ve
-- yarışma tanımları, şema, fonksiyonlar, cron işleri.
--
-- Sahibin kendi hesabı da silinir; telefonda yeniden giriş yapılır.
-- Storage'daki eski avatar dosyaları SQL'le silinemez (Supabase korur);
-- sahipsiz kalırlar, kimse göremez. İstenirse panelden silinir.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-22_yayin_oncesi_test_verisi_temizligi.sql

begin;

-- Soruların yazar alanı profile ON DELETE kuralsız bağlı; hesap silinmeden önce boşalt.
update public.questions set created_by = null where created_by is not null;

-- auth.users'a kuralsız (NO ACTION) bağlı tek tablo.
delete from public.suggested_questions;

-- Profil silinince reporter_id NULL olur; test bildirimleri hiç kalmasın.
delete from public.question_reports;

-- Odalar ve düellolar oyuncuya SET NULL ile de bağlı; yetim kalmasınlar.
delete from public.rooms;
delete from public.async_duels;
delete from public.tournament_matches;

-- Bütün hesaplar: kalan her şey CASCADE ile gider.
delete from auth.users;

-- Geçmiş lig haftaları (kademe geçmişi); işlev yeni haftayı gerektiğinde açar.
delete from public.league_weeks;

-- Doğrulama: hepsi 0 olmalı; içerik tabloları dolu kalmalı.
select
  (select count(*) from auth.users) as hesap,
  (select count(*) from public.profiles) as profil,
  (select count(*) from public.player_answers) as cevap,
  (select count(*) from public.coin_transactions) as jeton,
  (select count(*) from public.rooms) as oda,
  (select count(*) from public.async_duels) as duello,
  (select count(*) from public.friends) as arkadas,
  (select count(*) from public.analytics_events) as analitik,
  (select count(*) from public.questions) as soru_kalir,
  (select count(*) from public.lessons) as ders_kalir,
  (select count(*) from public.shop_items) as urun_kalir;

commit;
