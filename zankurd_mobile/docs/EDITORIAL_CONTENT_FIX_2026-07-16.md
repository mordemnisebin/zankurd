# Editoryal İçerik Düzeltmesi — 2026-07-16

## Neden

Canlı `questions` tablosunda (3.836 onaylı soru) yapılan tarama:

- **1.034** onaylı soruda Türkçe prompt kalıntısı var (`ı/ğ/ö/ü` sezgisi).
  Not: İki dilli soru havuzu (Pirs uygulaması gibi) kendi başına kusur
  değildir; asıl kusurlar aşağıdakiler.
- **98** adet `"X" anlamına gelen Kurmancî kelime hangisidir?` sorusunda
  çeldiriciler karışık dilli/anlamsızdı (ör. cevap `Nav`, çeldiriciler
  `Ben/Köy/Çok` — Türkçe kelimeler).
- **25** adet `Görsel etiketi "X" kavramını gösteriyor` sorusunda hem prompt
  şablon Türkçesiydi hem de çeldiriciler saçmaydı (`Ergatîf/Üç/Bir`), bazıları
  cevabı sızdırıyordu (soru `duh` iken şık `Duh`).
- **40** adet `Görseldeki 'X' etiketi hangi kategoriye aittir?` sorusu kendini
  cevaplıyor (doğru şık her zaman sorunun kategorisi).
- **10** adet `Kürt ve Kürdistan tarihi için X kavramının en uygun açıklaması`
  sorusunda çeldiriciler başka soruların cevaplarından rastgele kopyalanmış.
- **7** adet uygulama-meta soru ("ZanKurd için en dengeli politik içerik
  stratejisi", "en öğretici geri bildirim" vb.) quiz içeriği değil.
- **7** adet Cografya `en uygun Kurmancî kelime` sorusu Ziman'daki temiz
  eşlerinin kopyası; 3'ü (göl/orman/sınır) eşi olmadığı için düzeltilerek tutuldu.
- **3** tutarsız çeldiricili şablon (misafirperverlikte "karton para" vb.).

## Yapılan

`supabase/2026-07-16_editorial_content_fix.sql`:

1. **Yedek:** etkilenen tüm satırlar `questions_editorial_backup_20260716`
   tablosuna kopyalanır (geri alma sorgusu dosyanın başındadır).
2. **124 UPDATE:** kelime ve görsel sorularına Kurmancî prompt
   (`Bi Kurmancî "X" çi ye?` / `Di wêneyê de "X" tê nîşandan...`),
   tamamı tek dilli ve anlamca ilgili çeldiriciler, gerçek açıklamalar
   (`explanation_ku/tr`). Doğru şıkkın **metni ve harfi değişmez**; her
   UPDATE `and correct_option=...` guard'ı taşır.
3. **67 unapprove:** yukarıdaki çöp şablonlar `is_approved=false` yapılır
   (silinmez — geri döndürülebilir).

Offline bankada aynı aileden kalan 3 prompt da düzeltildi
(`offline_question_bank.dart`), 12/12 `question_bank_test` yeşil.

## Durum

- SQL migration **2026-07-16'da kullanıcı onayıyla CANLIYA UYGULANDI**
  (Management API). Doğrulama: onaylı soru 3.836 → 3.769; 98 `Bi Kurmancî`
  + 25 `Di wêneyê de` promptu canlıda; `Görsel*` şablonu onaylılarda 0;
  yedek tablo `questions_editorial_backup_20260716` 342 satır.
- Kategori başına onaylı soru sayısı kaldırmalardan sonra da her seviye
  için yeterli (en çok etkilenen Dîrok ~-22, Cografya ~-17).

## Kalan (sonraki oturumlar)

- ~900 bilgi sorusunun promptu hâlâ Türkçe (içerik doğru, dil karışık).
  İki seçenek: (a) kabul et — iki dilli havuz, Pirs benzeri; (b) kademeli
  Kurmancî çeviri. Karar ürün sahibinin.
- Şablon açıklamalar (`Pirsa wêneyî peyva X xurt dike`) yalnızca düzeltilen
  124 soruda yenilendi; kalan havuzda sürüyor.
