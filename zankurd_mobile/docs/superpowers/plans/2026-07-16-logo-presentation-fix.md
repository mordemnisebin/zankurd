# Logo Presentation Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Splash logosunun beyaz karesini görünmez kılmak ve onboarding logosunu telefon/masaüstünde belirgin büyütmek.

**Architecture:** Mevcut `AppLogo`, animasyonlar ve `LayoutBuilder` korunur. Yeni asset, widget veya paket eklenmeden yalnız splash zemini ve mevcut responsive boyut değerleri değiştirilir.

**Tech Stack:** Flutter, Dart, `flutter_test`, Playwright.

## Global Constraints

- Splash her temada `Colors.white` kullanır.
- Normal yükseklikte onboarding logosu 96 px olur.
- 720 px altı başlık 140 px, daha yüksek ekranlarda 180 px olur.
- Kısa yatay görünümün 48 px logosu ve `FittedBox` koruması değişmez.
- Yeni bağımlılık ve yeni asset yoktur.

---

### Task 1: Splash zeminini logo assetiyle birleştir

**Files:**
- Modify: `test/splash_screen_test.dart`
- Modify: `lib/src/screens/splash_screen.dart`

**Interfaces:**
- Consumes: `SplashScreen`, `AppLogo`, `Colors.white`
- Produces: Her temada beyaz splash yüzeyi

- [ ] **Step 1: Koyu temada beyaz splash zemini bekleyen testi ekle**

```dart
testWidgets('logo karesini gizlemek için her temada beyaz zemin kullanır', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: const SplashScreen(
        next: SizedBox.shrink(),
        duration: Duration(hours: 1),
      ),
    ),
  );
  await tester.pump();

  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
  expect(scaffold.backgroundColor, Colors.white);
});
```

- [ ] **Step 2: Testin mevcut koyu zemin nedeniyle kırmızı olduğunu doğrula**

Run: `flutter test test/splash_screen_test.dart`

Expected: FAIL; `AppTheme.bg` değeri `Colors.white` ile eşleşmez.

- [ ] **Step 3: Splash zeminini tek değere indir**

```dart
return Scaffold(
  backgroundColor: Colors.white,
```

- [ ] **Step 4: Splash testini yeşile çevir**

Run: `flutter test test/splash_screen_test.dart`

Expected: 3 test PASS.

### Task 2: Onboarding marka alanını büyüt

**Files:**
- Modify: `test/onboarding_hierarchy_test.dart`
- Modify: `lib/src/screens/onboarding_screen.dart`

**Interfaces:**
- Consumes: `LayoutBuilder`, `AppLogo`, mevcut `FittedBox`
- Produces: Normal yükseklikte 96 px logo; kısa yatay ekranda mevcut güvenli davranış

- [ ] **Step 1: Telefon ve masaüstü logo boyutu testlerini ekle**

```dart
testWidgets('normal yükseklikte onboarding logosu belirgindir', (
  tester,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));

  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<AppLogo>(find.byType(AppLogo)).width, 96);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
});
```

- [ ] **Step 2: Testin mevcut 68 px değer nedeniyle kırmızı olduğunu doğrula**

Run: `flutter test test/onboarding_hierarchy_test.dart`

Expected: FAIL; actual `68`, expected `96`.

- [ ] **Step 3: Mevcut responsive değerleri güncelle**

```dart
final headerHeight = compact
    ? 90.0
    : (constraints.maxHeight < 720 ? 140.0 : 180.0);

logoWidth: compact ? 48 : 96,
```

- [ ] **Step 4: İlgili testleri çalıştır**

Run: `flutter test test/onboarding_hierarchy_test.dart test/widget_test.dart test/splash_screen_test.dart`

Expected: Tüm testler PASS, overflow yok.

### Task 3: Genel ve görsel doğrulama

**Files:**
- Verify only

**Interfaces:**
- Consumes: tamamlanmış Flutter değişiklikleri
- Produces: analiz, test ve ekran kanıtı

- [ ] **Step 1: Statik analiz**

Run: `dart analyze`

Expected: `No issues found!`

- [ ] **Step 2: Tam test paketi**

Run: `flutter test --exclude-tags preview`

Expected: 0 failure.

- [ ] **Step 3: Flutter web ekran kontrolü**

Run the app at 390×844 and desktop width, then verify with Playwright:
- Splash beyaz zemin üzerinde karesiz görünür.
- Onboarding logosu belirgin ve ortalıdır.
- Konsolda hata ve ekranda overflow yoktur.
