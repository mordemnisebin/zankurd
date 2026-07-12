# ZanKurd Kültürel Modern 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Artefakttaki Kültürel Modern 2.0 tasarımını dört ana ekrana ve ortak tema bileşenlerine eksiksiz taşımak.

**Architecture:** Mevcut ekran akışları korunur; ortak görsel dil tema tokenları ve küçük, odaklı widgetlar üzerinden uygulanır. Her davranış değişikliği önce widget/regresyon testiyle sabitlenir.

**Tech Stack:** Flutter, Dart, Provider, SharedPreferences, flutter_test

## Global Constraints

- Yeni bağımlılık yok.
- Açık tema ayarlarda kalır; ilk kurulum koyu temadır.
- Kurmancî metin ve karakter doğruluğu korunur.
- Telefon ve tablet taşma üretmez.

---

### Task 1: Koyu tema varsayılanı

**Files:**
- Modify: `test/theme_default_test.dart`
- Modify: `lib/src/providers/theme_provider.dart`

- [ ] Testi ilk kurulumda `ThemeMode.dark` ve `Brightness.dark` bekleyecek şekilde yaz.
- [ ] Testin mevcut açık tema varsayılanıyla başarısız olduğunu doğrula.
- [ ] Provider varsayılanını ve boş tercih çözümlemesini koyu yap.
- [ ] Testi tekrar çalıştır ve geçtiğini doğrula.

### Task 2: Ortak kilim ilerleme ve Zana şîrove

**Files:**
- Create: `lib/src/widgets/kilim_progress_bar.dart`
- Modify: `lib/src/screens/quiz/quiz_widgets.dart`
- Modify: `lib/src/screens/quiz_screen.dart`
- Test: `test/kulturel_modern_quiz_test.dart`

- [ ] Kilim ilerleme ve `Şîrove · Zana` sözleşmesini testte tanımla.
- [ ] Testin eksik ortak widget/etiket nedeniyle başarısız olduğunu doğrula.
- [ ] Ortak ilerleme widgetını quiz ilerlemesine bağla ve şîrove başlığını güncelle.
- [ ] Testleri geçir.

### Task 3: Mastery sayaçlı kategori kartı

**Files:**
- Modify: `lib/src/screens/categories_tab.dart`
- Modify: `lib/src/data/mastery_store.dart`
- Test: `test/categories_tab_test.dart`

- [ ] Rozette unvan ile doğru cevap sayacını bekleyen testi yaz.
- [ ] Testin sayaç eksikliğiyle başarısız olduğunu doğrula.
- [ ] Kart modeline doğru cevap sayısını taşı ve rozette göster.
- [ ] Kategori testlerini geçir.

### Task 4: Ana sayfa ve sonuç sahnesi sözleşmesi

**Files:**
- Modify: `lib/src/screens/home_screen.dart`
- Modify: `lib/src/screens/home/hero_card.dart`
- Modify: `lib/src/screens/quiz_result_screen.dart`
- Test: `test/kulturel_modern_home_result_test.dart`

- [ ] Artefakttaki tek CTA, hızlı oyun, Zana ve sonuç eylemlerini testte tanımla.
- [ ] Eksik işaretlerin başarısızlığını doğrula.
- [ ] Mevcut akışları koruyarak görsel hiyerarşiyi ve sabit anahtarları tamamla.
- [ ] Testleri geçir.

### Task 5: Tam doğrulama

**Files:**
- Verify: `lib/`, `test/`

- [ ] `dart format --output=none --set-exit-if-changed lib test` çalıştır.
- [ ] `dart analyze` çalıştır.
- [ ] İlgili testleri, ardından tam `flutter test` paketini çalıştır.
- [ ] Flutter web'i çalıştır ve Playwright ile 390x844 ile tablet görünümünü doğrula.
