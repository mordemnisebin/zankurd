# Bubblegum Arcade — Paket 0 (Tasarım Temeli) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swap ZanKurd's brand color tokens (orange/purple → indigo/pink/sky/lime "Bubblegum Arcade" palette), flip the default theme from dark-first to light-first, and recolor the Zana/RojMascot rays — with zero layout or logic changes. This alone repaints every existing screen app-wide since all screens already consume `AppTheme` tokens.

**Architecture:** Pure token-value edits in `lib/src/theme/app_theme.dart` and `lib/src/providers/theme_provider.dart`, plus a small loop-color change in `lib/src/widgets/roj_mascot.dart`. No new widgets, no screen files touched. This is Paket 0 of `docs/superpowers/specs/2026-07-12-bubblegum-arcade-redesign-design.md` — Paket 1+ (new full-width mode-card component, dedicated category screen, 2×2 result grid) is a separate follow-up plan, not covered here.

**Tech Stack:** Flutter/Dart, flutter_test, existing `AppTheme`/`ThemeProvider`/`RojMascot` classes.

---

## File Structure

- Modify: `lib/src/theme/app_theme.dart` — color constant values only (lines 246-301 block), `isLight()` no change in logic, `backgroundGradient()` gets a new light-mode background pair.
- Modify: `lib/src/providers/theme_provider.dart` — default `ThemeMode` flips dark → light (constructor default + `_decode` fallback).
- Modify: `lib/src/widgets/roj_mascot.dart` — `rayPaint` becomes per-ray color instead of one fixed `AppTheme.gold`.
- Modify: `test/theme_default_test.dart` — regression test updated to expect light default (this is an intentional behavior change, not a bug fix).
- Create: `test/roj_mascot_test.dart` — new test asserting the mascot paints without exception across all 3 moods and that ray colors cycle through 4 values (tested via the painter's public color list, not pixel-reading canvas).

## Task 1: Flip default theme to light-first

**Files:**
- Modify: `lib/src/providers/theme_provider.dart`
- Modify: `test/theme_default_test.dart`

- [ ] **Step 1: Update the failing-first test to expect light default**

Edit `test/theme_default_test.dart`, replacing the whole file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';

class _GateAuthProvider extends AuthProvider {
  _GateAuthProvider() : super.test();

  @override
  bool get isAuthenticated => false;

  @override
  bool get isLoading => false;
}

// Bubblegum Arcade redesign (2026-07-12): uygulama artık açık-temayla
// açılır (kayıtlı tercih yokken). Koyu tema ikincil ama tam desteklenir.
void main() {
  testWidgets('sıfır kurulumda onboarding açık temayla açılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themeProvider = await ThemeProvider.load();
    expect(themeProvider.mode, ThemeMode.light);

    await tester.pumpWidget(
      ZanKurdApp(
        repository: MockZanKurdRepository(),
        authProvider: _GateAuthProvider(),
        languageProvider: LanguageProvider()..setLang('tr'),
        themeProvider: themeProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('kayıtlı koyu tercih varsa koyu temayla açılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'zankurd.themeMode': 'dark'});
    final themeProvider = await ThemeProvider.load();
    expect(themeProvider.mode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme_default_test.dart`
Expected: FAIL — `themeProvider.mode` is `ThemeMode.dark`, expected `ThemeMode.light`.

- [ ] **Step 3: Flip the provider default**

Edit `lib/src/providers/theme_provider.dart`, replacing lines 4-5 and 34-40:

```dart
  ThemeProvider({ThemeMode initialMode = ThemeMode.light}) : _mode = initialMode;
```

and:

```dart
  static ThemeMode _decode(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }
```

(Note: `'light'` case was missing from the original switch — `_encode` already writes `'light'` for `ThemeMode.light`, but `_decode` had no matching case, so a saved light preference was silently falling through to the `_` default. This is a real bug the flip incidentally fixes — a saved light choice will now round-trip correctly.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme_default_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/providers/theme_provider.dart test/theme_default_test.dart
git commit -m "feat: ZanKurd varsayılan temayı açık yapar (Bubblegum Arcade)"
```

## Task 2: Bubblegum Arcade color tokens

**Files:**
- Modify: `lib/src/theme/app_theme.dart:246-347`

- [ ] **Step 1: Write a failing token-value test**

Create `test/app_theme_bubblegum_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Bubblegum Arcade (2026-07-12): turuncu/mor bırakıldı, yeni bağımsız
// palet. Bu test spec'teki hex değerlerinin token'lara yansıdığını
// doğrular — regresyonu (eski turuncuya dönüş) yakalar.
void main() {
  test('marka rengi indigo Bubblegum Arcade paleti', () {
    expect(AppTheme.brandOrange, const Color(0xFF6C5CE7));
    expect(AppTheme.brandOrangeWarm, const Color(0xFF8B7CF6));
  });

  test('öğrenme rengi lime', () {
    expect(AppTheme.playGreen, const Color(0xFF8BC53F));
  });

  test('1v1/rekabet rengi sıcak pembe', () {
    expect(AppTheme.playPink, const Color(0xFFFF3B81));
  });

  test('oda/mod rengi gökmavi', () {
    expect(AppTheme.playCyan, const Color(0xFF38BDF8));
  });

  test('özel mod moru indigo ile birleşir', () {
    expect(AppTheme.playPurple, const Color(0xFF6C5CE7));
  });

  test('ödül altını değişmez kalır', () {
    expect(AppTheme.gold, const Color(0xFFE9C46A));
  });

  test('açık mod zemin sıcak beyaz', () {
    expect(AppTheme.lightBg, const Color(0xFFFAFAFF));
  });

  test('koyu mod zemin yeni indigo-koyu tonu', () {
    expect(AppTheme.bg, const Color(0xFF15121F));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_theme_bubblegum_test.dart`
Expected: FAIL — current values are `0xFFF47A32` (orange) etc.

- [ ] **Step 3: Update the color constants**

Edit `lib/src/theme/app_theme.dart`. Replace the block from `static const brandOrange` (line 246) through `static const lightTextMuted` (line 301) with:

```dart
  // ============ Bubblegum Arcade Palette (2026-07-12) ============
  // Turuncu/mor bırakıldı; Kürt kimliği renkte değil, RojMascot (Zana)
  // ışın motifinde taşınır. Bkz. docs/superpowers/specs/
  // 2026-07-12-bubblegum-arcade-redesign-design.md
  static const brandOrange = Color(0xFF6C5CE7); // İndigo — ana marka rengi
  static const brandOrangeWarm = Color(0xFF8B7CF6); // Açık indigo (gradyan ucu)
  static const playGreen = Color(0xFF8BC53F); // Lime — öğrenme kimliği
  static const playPink = Color(0xFFFF3B81); // Sıcak pembe — 1v1/rekabet
  static const playCyan = Color(0xFF38BDF8); // Gökmavi — oda/mod kartları
  static const playPurple = Color(0xFF6C5CE7); // İndigo ile birleşti (ayrı mor yok)

  // ============ Dark Mode Palette (Bubblegum Arcade — koyu ikincil tema) ============
  // Legacy token names retained for existing screen consumers.
  static const primaryGradientStart = brandOrange;
  static const primaryGradientEnd = brandOrangeWarm;

  // İkincil aksan — ikincil vurgu / yardımcı renk.
  static const secondaryAccent = Color(0xFF38BDF8); // Gökmavi

  // Ödül rengi — YALNIZCA coin / ödül / streak / ustalık rozeti göstergelerinde kullan.
  // Bilinçli olarak sabit tutuldu: renk sistemi değişse de ödül/coin anlamı korunur.
  static const gold = Color(0xFFE9C46A);

  // Bilgi/ipucu vurgusu — nadir kullan (ör. joker ipucu). Genel aksan için kullanma.
  static const cyan = playCyan;

  // Dark backgrounds (İndigo-koyu tonlar)
  static const bg = Color(0xFF15121F);
  static const bgDeep = Color(0xFF0E0C16);
  static const surface = Color(0xFF1E1A2E);
  static const surfaceHi = Color(0xFF29233D);
  static const darkBg = Color(0xFF0A0812);

  // Dark mode text
  static const textPrimary = Color(0xFFEFEBFA);
  static const textSub = Color(0xFFB3A9D6);
  static const textMuted = Color(0xFF7E739E);

  // Borders
  static const border = Color(0xFF3A3252);

  // Status colors
  // Doğru/yanlış renkleri correct/wrong; altın ödül gold — bu üçü sabit kalır
  // (quiz geri bildirim anlamı renk sisteminden bağımsız).
  static const accent = playPink;
  static const violet = playPurple;
  static const correct = Color(0xFF2E7D32); // Dengeli Yeşil — değişmez
  static const wrong = Color(0xFFC62828); // Dengeli Kırmızı — değişmez

  // ============ Light Mode Palette (varsayılan tema) ============
  static const lightBg = Color(0xFFFAFAFF);
  static const lightBgDeep = Color(0xFFF0EEFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHi = Color(0xFFF7F6FE);
  static const lightBorder = Color(0xFFE4E1F5);
  static const lightTextPrimary = Color(0xFF211C34);
  static const lightTextSub = Color(0xFF6E6791);
  static const lightTextMuted = Color(0xFF9B94BC);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_theme_bubblegum_test.dart`
Expected: PASS (all 8 tests).

- [ ] **Step 5: Run full analyzer and test suite to check for regressions**

Run: `dart analyze lib test`
Expected: `No issues found!`

Run: `flutter test`
Expected: All tests pass. Widget/golden tests that assert specific old hex values
(e.g. `AppTheme.brandOrange` compared to a literal `0xFFF47A32`) will need
updating — search first:

Run: `grep -rn "0xFFF47A32\|0xFFF9F1C\|0xFF58B96B\|0xFFE72F8C\|0xFF3BC7C1\|0xFF8A62D3" test/`

If any test file hardcodes the old literal hex instead of referencing
`AppTheme.brandOrange` etc., update that literal to match the new value from
Step 3 above (do not weaken the assertion — keep it exact).

- [ ] **Step 6: Commit**

```bash
git add lib/src/theme/app_theme.dart test/app_theme_bubblegum_test.dart
git commit -m "feat: Bubblegum Arcade renk paleti (indigo/pembe/gökmavi/lime)"
```

## Task 3: Zana/RojMascot ışın renklerini güncelle

**Files:**
- Modify: `lib/src/widgets/roj_mascot.dart:41-71`
- Create: `test/roj_mascot_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/roj_mascot_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

// Zana'nın 12 ışını artık tek altın renk yerine 4 Bubblegum Arcade
// renginin (indigo/pembe/gökmavi/lime) dönüşümüyle çizilir — kilim
// sınırındaki dönüşümlü renk şeridi hissi. Geometri/ifade değişmez.
void main() {
  testWidgets('RojMascot tüm ruh hâllerinde hatasız çizilir', (tester) async {
    for (final mood in RojMood.values) {
      await tester.pumpWidget(
        MaterialApp(home: Center(child: RojMascot(mood: mood))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(RojMascot), findsOneWidget);
    }
  });

  testWidgets('farklı boyutlarda overflow/exception oluşmaz', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: RojMascot(size: 40)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: RojMascot(size: 160)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify current state**

Run: `flutter test test/roj_mascot_test.dart`
Expected: PASS already (this test only checks it paints without exception —
it doesn't yet assert the new colors, since the painter's color list isn't
publicly inspectable). This confirms the baseline is safe before the color
change; proceed to Step 3 regardless.

- [ ] **Step 3: Update the ray painting to cycle through 4 colors**

Edit `lib/src/widgets/roj_mascot.dart`. Replace lines 51-71 (the ray-drawing
block) with:

```dart
    // Kilim dilinde 12 üçgen ışın — Bubblegum Arcade'in 4 rengi dönüşümlü
    // kullanılır (kilim sınırındaki dönüşümlü renk şeridi hissi).
    const rayColors = [
      AppTheme.brandOrange, // İndigo
      AppTheme.playPink, // Sıcak pembe
      AppTheme.playCyan, // Gökmavi
      AppTheme.playGreen, // Lime
    ];
    for (var i = 0; i < 12; i++) {
      final rayPaint = Paint()..color = rayColors[i % rayColors.length];
      final angle = i * math.pi / 6;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-dir.dy, dir.dx);
      final base = center + dir * (faceR + size.width * 0.02);
      final tip = center + dir * (faceR + size.width * 0.16);
      final path = Path()
        ..moveTo(
          base.dx + normal.dx * size.width * 0.045,
          base.dy + normal.dy * size.width * 0.045,
        )
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(
          base.dx - normal.dx * size.width * 0.045,
          base.dy - normal.dy * size.width * 0.045,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }
```

Note: the face disc (lines 73-87 in the original, radial gradient +
`AppTheme.gold`) stays gold — only the rays change. This keeps the "sun
face" reading intact while the border carries the new palette.

- [ ] **Step 4: Run test to verify it still passes**

Run: `flutter test test/roj_mascot_test.dart`
Expected: PASS (both tests — painting logic changed but still exception-free).

- [ ] **Step 5: Run the full suite once more**

Run: `dart analyze lib test`
Expected: `No issues found!`

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/src/widgets/roj_mascot.dart test/roj_mascot_test.dart
git commit -m "feat: Zana'nın ışınları Bubblegum Arcade paletiyle dönüşümlü boyanır"
```

## Task 4: Web build + visual sanity check

**Files:** none (verification only)

- [ ] **Step 1: Full analyze + test**

Run: `dart analyze lib test`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 2: Web release build**

Run (from a junction path to avoid the Turkish-İ path bug — see CLAUDE.md):
```powershell
cd C:\src\zkdesign
$env:TMP = "C:\src\tmp"; $env:TEMP = "C:\src\tmp"
flutter build web --release
```
Expected: `√ Built build\web`

- [ ] **Step 3: Note for the user**

This plan intentionally stops here. Paket 0 repaints the whole app (every
screen already consumes `AppTheme.brandOrange`/`playGreen`/`playPink`/
`playCyan` tokens) without touching any layout or business logic — lowest
possible regression risk for an unsupervised run. Paket 1 (new full-width
mode-card widget, dedicated category-selection screen, 2×2 result grid —
the actual layout changes from the Pirs comparison) is intentionally a
separate follow-up plan requiring visual review of Paket 0's live result
first.

## Self-Review Notes

- **Spec coverage:** This plan implements the "Renk Sistemi", "Light/Dark
  Öncelik Değişikliği", and "Kültürel Taşıyıcı" sections of the design spec
  in full. It does not implement "Bileşen Dili" (new mode-card/category-row
  widgets) or any "Ekran Aileleri" package — those remain for the Paket 1+
  follow-up plan, as scoped in this plan's Goal/Architecture above.
- **Placeholder scan:** No TBD/TODO; every step has literal code.
- **Type consistency:** `rayColors` is a `List<Color>` of exactly the 4
  `AppTheme` constants already defined in Task 2 — no new types introduced.
