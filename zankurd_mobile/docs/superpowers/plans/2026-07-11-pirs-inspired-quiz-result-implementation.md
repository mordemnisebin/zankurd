# Pirs-Inspired Quiz and Result (Paket 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quiz ve sonuç ekranlarının etkileşim aksanını Pirs-inspired `brandOrange` diline taşımak, kalın 3D şık gölgesini yumuşatmak ve solo sonuç vitrinini renkli skor vitrini yapmak; quiz/skor/joker/coin mantığına dokunmamak.

**Architecture:** `AppTheme.accent` artık `playPink` olduğundan quiz akışındaki tüm etkileşim vurguları pembeye kaymış durumda; bunlar tek tek `brandOrange`'a sabitlenir. Seçenek butonlarının A/B/C/D rozet paleti, doğru/yanlış semantiği ve timer'ın yeşil→amber→kırmızı geçişi korunur. Solo sonuç vitrini koyu yeşil `secondaryAccent→bgDeep` yerine `brandOrange→brandOrangeWarm` kutlama gradyanı alır; 1v1 kazanma/berabere/kaybetme gradyanları aynen kalır.

**Tech Stack:** Flutter, Dart, Material 3, Provider, flutter_test, Playwright CLI; yeni dependency yok.

## Global Constraints

- `_answer`, `submitAnswer`, `awardQuizCoins`, joker mekanikleri, multiplayer senkron ve navigation davranışı değişmeyecek.
- Seçenek rozet paleti (`_badgePalette`), doğru/yanlış gradyanları ve timer renk geçişi korunacak (doğru cevap önceden ima edilmez).
- `review_screen.dart` ve `favorite_questions_screen.dart` DEĞİŞMEZ (zaten ScreenIdentityHeader + token kullanıyor); yalnızca doğrulamada smoke edilir.
- `core/widgets/zankurd_quiz_option.dart` ve golden'ları bu pakette değişmez.
- Light mode birincil; dark mode okunabilir kalacak; 360 px'de overflow yok.
- Çalışma `codex/pirs-inspired-package-03` branch'inde, `.worktrees/pirs-inspired-package-03` worktree'sinde yapılacak.

---

### Task 1: Quiz Ekranı Etkileşim Aksanı

**Files:**
- Modify: `lib/src/screens/quiz_screen.dart:713-765` (progress bar), `:806-875` (practice rating), `:876-909` (Sonraki CTA)
- Create: `test/quiz_accent_test.dart`

**Interfaces:**
- Preserves: `_next`, `_answer`, `_submitPracticeRating`, `canPressNext` mantığı.
- Produces: CTA'da `ValueKey('quiz-next-button')`.

- [ ] **Step 1: Aksan sözleşme testini yaz**

`test/quiz_accent_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => SoundProvider()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('Sonraki CTA brandOrange dolgu taşır', (tester) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [repository.questions.first],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    expect(
      button.style?.backgroundColor?.resolve({}),
      AppTheme.brandOrange,
    );
  });

  testWidgets('aktif soru segmenti brandOrange bekler', (tester) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: repository.questions.take(3).toList(),
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final segments = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) {
          final deco = c.decoration;
          return deco is BoxDecoration && deco.color == AppTheme.brandOrange;
        });
    expect(segments, isNotEmpty);
  });

  testWidgets('şık kartı katı 3D gölge taşımaz', (tester) async {
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstAnswer = question.displayAnswers.first;
    final option = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(firstAnswer).first,
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final deco = option.decoration as BoxDecoration;
    expect(deco.boxShadow, isNotNull);
    for (final shadow in deco.boxShadow!) {
      expect(shadow.blurRadius, greaterThan(0));
    }
  });
}
```

- [ ] **Step 2: Testin pembe aksan ve katı gölge nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/quiz_accent_test.dart`

Expected: `quiz-next-button` key'i olmadığı, aktif segment `accent` (pink) olduğu ve şık gölgesi `blurRadius: 0` olduğu için FAIL. (Üçüncü test Task 2'de geçer; bu görevde ilk iki testi geçir.)

- [ ] **Step 3: quiz_screen.dart aksanlarını uygula**

Progress bar (klasik bar, satır ~726):

```dart
color: AppTheme.brandOrange,
```

Segment şeridi (satır ~747-753):

```dart
: i == index
? AppTheme.brandOrange
: AppTheme.surfaceHiColor(context),
...
BoxShadow(
  color: AppTheme.brandOrange.withValues(alpha: 0.45),
  blurRadius: 6,
),
```

Practice rating butonları: `Zor` → `backgroundColor: AppTheme.brandOrangeWarm`, `Navîn` → `backgroundColor: AppTheme.playCyan`, `Hêsan` → `AppTheme.correct` (değişmez).

Sonraki CTA (`FilledButton.icon`): key ekle ve renkleri değiştir:

```dart
: FilledButton.icon(
    key: const ValueKey('quiz-next-button'),
    style: FilledButton.styleFrom(
      backgroundColor: AppTheme.brandOrange,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: 2,
      shadowColor: AppTheme.brandOrange.withValues(alpha: 0.3),
    ),
    ...
  ),
```

- [ ] **Step 4: İlk iki testin geçtiğini doğrula**

Run: `flutter test test/quiz_accent_test.dart --plain-name "Sonraki CTA brandOrange dolgu taşır"`

Run: `flutter test test/quiz_accent_test.dart --plain-name "aktif soru segmenti brandOrange bekler"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/quiz_screen.dart test/quiz_accent_test.dart
git commit -m "ui: align quiz interaction accents to brandOrange"
```

### Task 2: Quiz Widget Aksanı ve Yumuşak Şık Gölgesi

**Files:**
- Modify: `lib/src/screens/quiz/quiz_widgets.dart:325` (skor başlığı ikonu), `:655-675` (şık border/gölge), `:719-727` (şık boxShadow), `:983-1001` (joker aktif), `:1405-1446` (multiplayer bekleme)

**Interfaces:**
- Preserves: `_badgePalette`, `correctGradient`/`wrongGradient`, timer renk geçişi, tüm callback'ler.

- [ ] **Step 1: Kalan testin hâlâ başarısız olduğunu doğrula**

Run: `flutter test test/quiz_accent_test.dart --plain-name "şık kartı katı 3D gölge taşımaz"`

Expected: `blurRadius: 0` nedeniyle FAIL.

- [ ] **Step 2: quiz_widgets.dart değişikliklerini uygula**

Skor başlığı ikonu (satır ~325): `iconColor: AppTheme.accent` → `iconColor: AppTheme.brandOrange`.

Şık "kontrol ediliyor" border'ı (satır ~660): `? AppTheme.accent` → `? AppTheme.brandOrange`.

Şık 3D gölge rengi (satır ~673-674): `? const Color(0xFFFF6B6B)` → `? AppTheme.brandOrange`.

Şık boxShadow — katı 4 px taban yerine yumuşak gölge (satır ~719-727):

```dart
boxShadow: isPressed
    ? []
    : [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.28),
          offset: const Offset(0, 4),
          blurRadius: 10,
          spreadRadius: -2,
        ),
      ],
```

Joker aktif durumu (satır ~983-1001): üç `AppTheme.accent` kullanımını `AppTheme.brandOrange` yap (`wrong` dalları aynen kalır).

Multiplayer bekleme overlay'i (satır ~1405-1446): üç `AppTheme.accent` kullanımını `AppTheme.brandOrange` yap.

- [ ] **Step 3: Tüm aksan testlerini çalıştır**

Run: `flutter test test/quiz_accent_test.dart`

Expected: 3/3 PASS.

- [ ] **Step 4: Quiz regresyonlarını çalıştır**

Run: `flutter test test/widget_test.dart --plain-name "quiz"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/quiz/quiz_widgets.dart
git commit -m "ui: soften quiz option shadows and unify accents"
```

### Task 3: Sonuç Ekranı — Renkli Skor Vitrini ve CTA

**Files:**
- Modify: `lib/src/screens/quiz_result_screen.dart:397-409` (solo gradyan/border), `:469-486` (vitrin container), `:975-990` (XP aksan çizgisi), `:1028-1055` (ana CTA)
- Create: `test/quiz_result_visual_test.dart`

**Interfaces:**
- Preserves: 1v1 kazanma/berabere/kaybetme gradyanları, metric tile'lar, `ReviewScreen` push, coin/XP mantığı.
- Produces: vitrin container'ında `ValueKey('result-score-header')`, CTA'da `ValueKey('result-home-button')`.

- [ ] **Step 1: Görsel sözleşme testini yaz**

`test/quiz_result_visual_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => ChangeNotifierProvider(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

QuizResultScreen buildScreen(MockZanKurdRepository repository) {
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 1840,
    correctCount: 8,
    wrongCount: 2,
    totalQuestions: 10,
    bestStreak: 5,
    coinsAwarded: 120,
    answerRecords: const [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Ev gotin çi wateyê dide?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: 'Rast bersiv A ye.',
      ),
    ],
  );
}

void main() {
  testWidgets('solo vitrin brandOrange kutlama gradyanı taşır', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('result-score-header')),
    );
    final decoration = header.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors, [AppTheme.brandOrange, AppTheme.brandOrangeWarm]);
  });

  testWidgets('ana CTA brandOrange dolgu taşır', (tester) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('result-home-button')),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('result-home-button')),
    );
    expect(
      button.style?.backgroundColor?.resolve({}),
      AppTheme.brandOrange,
    );
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Testin koyu yeşil vitrin nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/quiz_result_visual_test.dart`

Expected: key'ler olmadığı için FAIL.

- [ ] **Step 3: Sonuç ekranını uygula**

Solo header gradyanı (satır ~397-401):

```dart
: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.brandOrange, AppTheme.brandOrangeWarm],
  );
```

Solo border (satır ~409): `AppTheme.secondaryAccent.withValues(alpha: 0.45)` → `AppTheme.brandOrange.withValues(alpha: 0.45)`.

Vitrin container'ına key (satır ~471): `child: Container(` → `child: Container(key: const ValueKey('result-score-header'),`.

Vitrin glow (satır ~483): `: AppTheme.secondaryAccent,` → `: AppTheme.brandOrange,`.

XP aksan çizgisi (satır ~983): `color: AppTheme.accent` → `color: AppTheme.brandOrange`.

Ana CTA (satır ~1030-1032): key ekle ve rengi değiştir:

```dart
child: FilledButton.icon(
  key: const ValueKey('result-home-button'),
  style: FilledButton.styleFrom(
    backgroundColor: AppTheme.brandOrange,
    ...
  ),
```

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/quiz_result_visual_test.dart test/result_before_after_test.dart`

Expected: PASS. (`result_before_after_test`'in yeniden ürettiği PNG'yi `git checkout --` ile geri al.)

- [ ] **Step 5: Commit**

```bash
git checkout -- docs/screenshots/phase2c
git add lib/src/screens/quiz_result_screen.dart test/quiz_result_visual_test.dart
git commit -m "ui: give result screen orange score showcase"
```

### Task 4: Paket Doğrulaması ve Görsel Kanıt

**Files:**
- Create: `docs/screenshots/pirs-inspired/package-03/` altındaki screenshotlar.

- [ ] **Step 1: Format kontrolü**

Run:

```bash
dart format lib/src/screens/quiz_screen.dart lib/src/screens/quiz/quiz_widgets.dart lib/src/screens/quiz_result_screen.dart test/quiz_accent_test.dart test/quiz_result_visual_test.dart
```

Expected: exit 0.

- [ ] **Step 2: Statik analiz**

Run: `dart analyze lib test`

Expected: `No issues found!`

- [ ] **Step 3: Odaklı ve tam testler**

Run:

```bash
flutter test test/quiz_accent_test.dart test/quiz_result_visual_test.dart
flutter test
```

Expected: tüm testler PASS; test koşusunun ürettiği phase2b/2c PNG'lerini geri al.

- [ ] **Step 4: Release web build**

Run: `flutter build web --release` (önce `$env:TMP="C:\src\tmp"; $env:TEMP="C:\src\tmp"`)

Expected: `build/web` başarıyla oluşur.

- [ ] **Step 5: Playwright görsel matrisi**

Release build'i yerel sunucuda aç, misafir girişiyle bir seviye quiz'i başlat ve şu kareleri al:

```text
docs/screenshots/pirs-inspired/package-03/light-390x844-quiz-question.png  (soru, cevaplamadan)
docs/screenshots/pirs-inspired/package-03/light-390x844-quiz-reveal.png    (cevap sonrası doğru/yanlış reveal)
docs/screenshots/pirs-inspired/package-03/dark-390x844-quiz-question.png   (dark tema soru)
docs/screenshots/pirs-inspired/package-03/light-390x844-result.png         (quiz bitince sonuç vitrini)
```

Her karede overflow, kesilen Kurmancî metin, katı 3D gölge ve pembe etkileşim aksanı OLMADIĞINI; doğru/yanlış renk semantiğinin korunduğunu doğrula. Console error/warning ve 4xx/5xx asset isteği olmamalı.

- [ ] **Step 6: Logic diff audit**

Run:

```bash
git diff HEAD~3..HEAD -- lib/src/screens
git diff --check HEAD~3..HEAD
```

`_answer`, `submitAnswer`, `awardQuizCoins`, `spendCoins`, `Navigator` çağrılarında davranış farkı olmadığını doğrula.

- [ ] **Step 7: Final doğrulama commit'i**

```bash
git add docs/screenshots/pirs-inspired/package-03
git commit -m "docs: verify Pirs-inspired quiz and result"
```

## Sonraki Paket

Bu paket görsel olarak onaylandıktan sonra ayrı planla Paket 4'e geçilir: matchmaking, room, 1vs1/team, contest, tournament, leaderboard ve friends ekranları. Bu dosyalar bu planda değiştirilmez.
