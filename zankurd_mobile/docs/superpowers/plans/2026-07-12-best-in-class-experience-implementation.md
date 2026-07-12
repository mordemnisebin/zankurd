# ZanKurd Best-in-Class Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ZanKurd'un öğrenme, oyun ve sosyal özelliklerini yönlendirilmiş ve tutarlı beş sekmeli deneyimde birleştirmek.

**Architecture:** Mevcut ekranlar korunur ve iki yeni merkez ekran tarafından birleştirilir. Quiz davranışı açık bir deneyim enum'u ile ayrılır; öğrenme yolu mevcut Lesson ve tamamlanma verisini kullanır.

**Tech Stack:** Flutter, Dart, Provider, SharedPreferences, flutter_test

## Global Constraints

- Yeni paket eklenmeyecek.
- Mevcut özellik ve kayıtlı ilerleme verisi korunacak.
- Kurmancî metinler doğru karakterlerle yazılacak.
- Telefon ve tablet yerleşimlerinde overflow olmayacak.

---

### Task 1: Yönlendirilmiş öğrenme yolu

**Files:** `lib/src/screens/learning_screen.dart`, `test/learning_path_test.dart`

- [ ] Yol düğümü durumlarını bekleyen widget testini yaz ve kırmızı çalıştır.
- [ ] Mevcut Lesson listesini tamamlanan, sıradaki ve kilitli düğümlere dönüştür.
- [ ] Mastery hedef düğümünü yol sonuna ekle ve testi geçir.

### Task 2: Yeni alt navigasyon ve Bilîze merkezi

**Files:** `lib/src/screens/app_shell.dart`, `lib/src/screens/play_hub_screen.dart`, `test/app_shell_navigation_test.dart`

- [ ] Beş yeni etiketi ve ortadaki Bilîze eylemini testte tanımla.
- [ ] Bilîze merkezinde 1vs1, günlük yarışma, çark ve turnuva girişlerini bağla.
- [ ] CategoriesTab'i öğrenme merkezinden erişilebilir tut ve testi geçir.

### Task 3: Öğrenme ve yarışma quizleri

**Files:** `lib/src/screens/quiz_screen.dart`, `lib/src/screens/learning_screen.dart`, `test/quiz_experience_test.dart`

- [ ] `QuizExperience.learning` için zamanlayıcı/skor/joker görünmezliği testini yaz.
- [ ] Enum ve görünürlük kurallarını uygula; ders quizlerini learning yap.
- [ ] Rekabet girişlerinin mevcut davranışını koruyan testi geçir.

### Task 4: Akıllı günlük Zana hedefi

**Files:** `lib/src/screens/home_screen.dart`, `lib/src/widgets/zana_daily_card.dart`, `test/zana_daily_focus_test.dart`

- [ ] Tek hedef, ilerleme ve CTA sözleşmesini testte tanımla.
- [ ] Mevcut günlük görev verisinden öncelikli öğrenme hedefi üret.
- [ ] Kartı öğrenme yoluna bağla ve testi geçir.

### Task 5: Civak ve kategori ligleri

**Files:** `lib/src/screens/community_screen.dart`, `lib/src/screens/leaderboard_screen.dart`, `lib/src/screens/app_shell.dart`, `test/community_screen_test.dart`

- [ ] Ligler/Heval sekmelerini ve kategori filtresini testte tanımla.
- [ ] Mevcut LeaderboardScreen ile FriendsScreen'i Civak içinde birleştir.
- [ ] Kategori seçimini liderlik yenilemesine bağla ve testi geçir.

### Task 6: Sosyal görev ve görsel tutarlılık

**Files:** `lib/src/screens/community_screen.dart`, `lib/src/theme/app_theme.dart`, ilgili testler

- [ ] Arkadaş görevi özet kartını ve tek ana CTA kuralını testle.
- [ ] Ortak başlık/spacing/radius kullanımını yeni ekranlarda uygula.
- [ ] 360 px ve tablet overflow testlerini geçir.

### Task 7: Tam doğrulama

- [ ] Değişen dosyalarda format kontrolü çalıştır.
- [ ] `dart analyze` çalıştır.
- [ ] İlgili testler ve tam `flutter test` paketini çalıştır.
- [ ] Web build alıp Playwright ile telefon/tablet görünümünü kontrol et.
