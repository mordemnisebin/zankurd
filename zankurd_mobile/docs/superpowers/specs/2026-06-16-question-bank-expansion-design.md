# Soru Bankası Genişletme — Tasarım (2026-06-16)

## Amaç
Mevcut 990 soruluk bankayı ~500+ **özgün, bilgi-sınayan** soruyla genişletmek.
Mevcut sorular çoğunlukla kolay "X kelimesi Türkçede ne demek" kalıbında ve kültürel
derinliği zayıf. Yeni sorular bunu telafi edecek.

## Kapsam & Hedef
- **Adet:** ~500+ (turlar halinde, ~90/tur).
- **Hedef depolar:** Hem canlı Supabase DB (`public.questions`) hem offline Dart bank
  (`lib/src/data/offline_question_bank.dart`). İkisi senkron tutulur.
- **Kategoriler (6, eşit ağırlık):** Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk.

## İçerik İlkeleri
1. **Bilgi-sınayan, özgün sorular.** Çeviri/ezber kalıbından kaçın; okuyunca bilgi
   gerektiren sorular.
2. **Zorluk dağılımı (az kolay):** ~%10 (1), %20 (2), %30 (3), %25 (4), %15 (5).
3. **Doğruluk:** Yalnızca yerleşik, emin olunan bilgiler. Belirsiz ayrıntılar
   (ör. enstrüman tel sayısı) yazılmaz. Yanlış bilgi yayınlamaktansa soru atlanır.
4. **İdeolojik-kültürel yön:** Kürt özgürlük hareketinin paradigması ve kültürel-
   entelektüel tarihi soru seçiminde öne çıkarılır — eğitsel/bilgi formatında:
   demokratik konfederalizm, jineolojî, "Jin Jiyan Azadî", demokratik ulus, kadın
   özgürlüğü, ekoloji, eş başkanlık, Newroz/Kawa direniş anlatısı, dil ve kültürel
   direniş, hareketin düşünsel figürleri/kavramları. **Sınır:** şiddeti yücelten ya da
   propaganda/örgütlenme çağrısı içerik üretilmez; fikirler ve tarih eğitsel işlenir.
5. **Hassas tarih dengesi:** Modern siyasi çatışma ayrıntısından çok kültürel/edebî/
   düşünsel/klasik tarih ağırlıklı; hareket paradigması kavramsal düzeyde işlenir.

## Test-Tasarım Kalite Kuralları
- **Cevap-uzunluğu yanlılığını kır:** Doğru cevap sistematik olarak en uzun şık olmasın.
  Çeldiriciler doğru cevapla benzer uzunlukta; doğru cevap bazen kısa/orta tutulur.
- **Çeldiriciler makul:** Rastgele değil, akla yatkın ama yanlış seçenekler.
- **Tekrar yok:** Yeni promptlar mevcut 990 ile ve birbirleriyle çakışmaz (prompt-bazlı
  benzersizlik kontrolü).
- **Format:** Ağırlıklı çoktan seçmeli (4 şık); bir kısmı doğru/yanlış (Rast/Şaş).

## Şema
**Supabase `public.questions`:** category_id (categories.name FK), language_code='ku-kmr',
prompt, option_a..d, correct_option ('A'..'D'), explanation, difficulty (1-5),
is_approved=true, question_type ('multiple_choice'|'true_false'), image_url (null),
source_url='zankurd_curated_v3'.

**Offline `QuizQuestion`:** id ('offline_XXXX' sıralı), category, prompt, answers[],
correctAnswer, explanation, difficulty, type. Şıklar Supabase'de A-D sırası; offline'da
`answers` listesi aynı sırada, `correctAnswer` doğru metin.

## Yürütme (turlar)
1. **Doğrulama partisi:** kategori başına 3 (~18 soru) sohbette sunulur → kullanıcı
   ideolojik yön + cevap uzunluğu + tarzı onaylar. **Üretime yazılmadan.**
2. Onay sonrası her tur ~90 soru: önce offline bank'a eklenir, `question_bank_test`
   çalıştırılır; geçince Supabase'e UTF-8 güvenli Python (`json.dumps` + urllib,
   `User-Agent: curl/8.0`) ile toplu INSERT edilir.
3. Her tur sonrası kullanıcı kaliteyi gözden geçirir; "devam" ile sonraki tur.
4. ~500 için 5-6 tur.

## Doğrulama
- `question_bank_test.dart`: benzersiz id, doğru cevap şıklarda, geçerli kategori,
  zorluk 1-5, benzersiz şıklar, prompt'ta teknik önek yok.
- Supabase tarafında: INSERT sonrası count artışı + örnek prompt karakter kontrolü.
- `dart analyze` temiz, tüm testler yeşil.

## Riskler
- **Doğruluk:** En büyük risk. Azaltma: yalnızca emin bilgiler, tur-bazlı kullanıcı
  incelemesi, source_url etiketiyle izlenebilirlik.
- **Üretim DB kirlenmesi:** Doğrulama partisi üretime yazılmadan onaylanır; her tur
  source_url='zankurd_curated_v3' ile etiketli → gerekirse toplu geri alınabilir.
