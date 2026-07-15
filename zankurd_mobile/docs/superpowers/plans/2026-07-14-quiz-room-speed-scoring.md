# Quiz, Oda ve Hız Bazlı Puanlama Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 1v1 ve özel odalarda daha uzun, oda sahibinin belirlediği soru süresi; cevap hızına göre adil puan; yarışma sonunda açıklamalı sonuç ve odada tekrar oynama akışı sağlamak.

**Architecture:** Süre `GameRoom` içinde taşınacak ve çevrim içi oda oluşturma/join verisiyle eşlenecek. Hız puanı, doğru cevap ve ölçülen `responseMs` üzerinden saf bir yardımcı fonksiyonda hesaplanacak; sonuç ekranı tüm cevap kayıtlarını açıklamalarıyla gösterecek. UI sadeleştirmeleri mevcut ekran sınırlarında küçük değişikliklerle yapılacak.

**Tech Stack:** Flutter/Dart, Supabase repository, Flutter widget tests, mevcut `SeenQuestionStore` ve günlük seed mekanizması.

## Global Constraints

- Türkçe cevap ver; Kurmancî metinleri mevcut dil yardımcılarıyla ve doğru karakterlerle yaz.
- Büyük refactor yapma; mevcut kirli çalışma ağacındaki ilgisiz değişiklikleri koru.
- Üretim kodundan önce her davranış için başarısız test yaz ve çalıştır.
- Değişiklikten sonra önce `dart analyze`, ardından ilgili Flutter testleri çalıştır.
- Git/GitHub MCP kullanma; commit/push yapma.

### Task 1: Süre ve hız puanı sözleşmesi

**Files:**
- Create: `lib/src/game/speed_score.dart`
- Modify: `lib/src/models/room.dart`
- Modify: `lib/src/models/answer_record.dart`
- Test: `test/speed_score_test.dart`

- [x] 1. Failing tests: 20/30/45/60 saniyelik süre seçeneklerini, doğru cevapta hız puanını, yanlış/süre aşımında sıfır bonusu ve geçerli aralığı tanımla.
- [x] 2. `dart test test/speed_score_test.dart` ile beklenen kırmızı sonucu doğrula.
- [x] 3. `SpeedScore.calculate({required int responseMs, required int limitSeconds, required bool correct})` saf fonksiyonunu ekle; doğru ve hızlı cevapta taban puan + hız bonusu, yanlış/timeout'ta bonus 0 olsun.
- [x] 4. `GameRoom.secondsPerQuestion` alanını ve `copyWith` desteğini ekle; varsayılanı 30 yap.
- [x] 5. Testleri yeşile getir.

### Task 2: Oda sahibi ayarları ve veri taşıma

**Files:**
- Modify: `lib/src/screens/home_screen.dart`
- Modify: `lib/src/screens/room_screen.dart`
- Modify: `lib/src/data/zankurd_repository.dart`
- Modify: `lib/src/data/mock_zankurd_repository.dart`
- Modify: `lib/src/data/supabase_zankurd_repository.dart`
- Modify: `test/supabase_repository_test.dart`

- [x] Oda kurma ekranında kategori ve süre seçimlerini yalnızca host için göster.
- [x] Seçimleri `createOnlineRoom` imzasına ve `GameRoom` nesnesine taşı.
- [x] Supabase insert/join dönüşünde `seconds_per_question` alanını yaz/oku; eski veride 30 saniyeye geri düş.
- [x] Oda ekranında seçili kategori ve süreyi görünür göster; host değiştirince güvenli şekilde kaydet.
- [x] Repository sözleşme testlerini ekle ve çalıştır.

### Task 3: Quiz akışı ve hız puanı entegrasyonu

**Files:**
- Modify: `lib/src/screens/quiz_screen.dart`
- Modify: `lib/src/screens/quiz/quiz_widgets.dart`
- Modify: `lib/src/data/zankurd_repository.dart`
- Modify: `lib/src/data/mock_zankurd_repository.dart`
- Test: `test/quiz_speed_scoring_test.dart`

- [x] Cevap verilmeden otomatik geçişi yakalayan başarısız widget/unit test yaz.
- [x] Timer ve kalan saniye hesabını `room.secondsPerQuestion` ile çalıştır.
- [x] Cevap sonrası oyuncuya soruyu görüp işaretlemesi için sabit reveal/next akışı ver; multiplayer senkronunu bozma.
- [x] `responseMs` değerini mevcut cevap kaydına ve repository submit akışına taşı.
- [x] Doğru cevap hız bonusunu oyuncu skoruna ve sonuç kayıtlarına uygula.
- [x] İlgili quiz testlerini çalıştır.

### Task 4: Sonuç ekranı ve odada devam

**Files:**
- Modify: `lib/src/screens/quiz_result_screen.dart`
- Modify: `lib/src/screens/room_screen.dart`
- Modify: `lib/src/screens/quiz_screen.dart`
- Test: `test/quiz_result_visual_test.dart`

- [x] Sonuç ekranında her soru için seçilen cevap, doğru cevap ve açıklamayı göster; açıklamalar yarışma sırasında gösterilmesin.
- [x] Hız bonusunu sonuç özeti ve oyuncu karşılaştırmasında göster.
- [x] “Dîsa bilîze/Devam et” oda ekranına dönsün; oda bağlamı korunarak yeni tur başlatılabilsin.
- [x] Sonuç ekranı widget testlerini güncelle.

### Task 5: Ana ekran, öğrenme alanı ve soru havuzu

**Files:**
- Modify: `lib/src/providers/theme_provider.dart`
- Modify: `lib/src/screens/home/home_header.dart`
- Modify: `lib/src/screens/learning_screen.dart`
- Modify: `lib/src/data/mock_zankurd_repository.dart`
- Modify: `lib/src/data/supabase_zankurd_repository.dart`
- Modify: `lib/src/screens/quiz/quiz_widgets.dart`
- Test: `test/theme_default_test.dart`, `test/learning_screen_test.dart`, `test/question_cache_test.dart`

- [x] Açık temayı varsayılan yap; dil/tema kontrollerini ana ekranda sabit ve erişilebilir tut.
- [x] Öğrenme alanını kategori → soru çözme/ders/flaş kartı girişleriyle sadeleştir.
- [x] Görsel sorularda asset/network fallback ve daha büyük soru/şık ölçülerini doğrula.
- [x] Günlük yarışmayı genel havuzdan UTC gün seed'iyle, herkes için aynı ve tekrar azaltılmış seçimle besle.
- [x] UI testleri ve soru seçim testlerini çalıştır.

### Final Verification

- [x] `dart analyze`
- [x] İlgili test dosyaları
- [x] Gerekirse `flutter test`
- [x] UI değişiklikleri için Flutter web ekran kontrolü ve taşma/navigasyon doğrulaması
