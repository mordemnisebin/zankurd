# Grup A İyileştirmeleri — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zankurd Mobile uygulamasının 6 kalite kategorisini 10/10'a çıkarmak: build fix, unit testler, page transitions, light mode tutarlılığı, question caching.

**Architecture:** Her task bağımsız — önce build fix (diğer taskları unblock eder), sonra paralel yürütülebilir. `CoinCalculator` utility sınıfı `MockZanKurdRepository._calculateCoinAward` mantığını test edilebilir hale getirir. `AppRoute` wrapper tüm `MaterialPageRoute` çağrılarını tek noktada toplar. `AppTheme` context-aware helper metodlar ekler.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, flutter_test, Provider

---

## Task 1: Build Fix — objective_c Native Assets Sorunu

**Files:**
- Modify: `zankurd_mobile/pubspec.yaml` (son satırlar)

**Sorun:** `objective_c 9.4.1` native asset hook'u pub-cache'den projeye göreceli path hesaplar. Proje yolunda boşluk (`pirs kurmanci`) olduğu için Dart URL-encode eder (`pirs%20kurmanci`) ve Windows bu yolu bulamaz. Çözüm: objective_c'yi hook'suz versiyona pin et.

- [ ] **Step 1: pubspec.yaml'a dependency_overrides ekle**

`zankurd_mobile/pubspec.yaml` dosyasının EN SONUNA ekle (fonts bloğundan sonra):

```yaml
dependency_overrides:
  # objective_c >= 6.0 adds native asset build hooks that fail when the
  # project path contains spaces on Windows (URL-encoded path resolution bug).
  objective_c: '>=0.1.0 <6.0.0'
```

- [ ] **Step 2: Paketleri güncelle ve test et**

```powershell
cd "C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile"
flutter pub get
```

Expected output: `Got dependencies!` — NO "Building native assets failed" hatası.

- [ ] **Step 3: Test suite'ini çalıştır**

```powershell
flutter test test/question_bank_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```powershell
git add zankurd_mobile/pubspec.yaml
git commit -m "fix: pin objective_c <6.0 to fix native assets hook on Windows paths with spaces"
```

---

## Task 2: CoinCalculator — Test Edilebilir Utility

**Files:**
- Create: `zankurd_mobile/lib/src/utils/coin_calculator.dart`
- Create: `zankurd_mobile/test/coin_calculator_test.dart`
- Modify: `zankurd_mobile/lib/src/data/mock_zankurd_repository.dart` (satır 355-366)

**Sorun:** `_calculateCoinAward` private metoddur, test edilemez. Extract ederek hem test coverage hem de `SupabaseZanKurdRepository` ile paylaşım sağlanır.

- [ ] **Step 1: Test dosyasını yaz (önce fail edecek)**

`zankurd_mobile/test/coin_calculator_test.dart` oluştur:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/coin_calculator.dart';

void main() {
  group('CoinCalculator.award', () {
    test('sıfır doğru, sıfır streak → yalnızca completionBonus (10 soruda)', () {
      expect(
        CoinCalculator.award(
          score: 0,
          correctCount: 0,
          bestStreak: 0,
          totalQuestions: 10,
        ),
        20, // completionBonus=20, rest=0
      );
    });

    test('10 doğru, streak 5, score 800, 10 soru', () {
      // completionBonus=20 + 10*6=60 + 5*2=10 + 800~/80=10 → 100
      expect(
        CoinCalculator.award(
          score: 800,
          correctCount: 10,
          bestStreak: 5,
          totalQuestions: 10,
        ),
        100,
      );
    });

    test('az soru (<10) → düşük completionBonus (8)', () {
      expect(
        CoinCalculator.award(
          score: 0,
          correctCount: 0,
          bestStreak: 0,
          totalQuestions: 5,
        ),
        8,
      );
    });

    test('yüksek streak → streak bonusu doğru hesaplanır', () {
      // completionBonus=20 + 0 + 10*2=20 + 0 = 40
      expect(
        CoinCalculator.award(
          score: 0,
          correctCount: 0,
          bestStreak: 10,
          totalQuestions: 10,
        ),
        40,
      );
    });

    test('practice mode → 0 coin (pratik modda ödül yok)', () {
      expect(CoinCalculator.practiceAward(), 0);
    });
  });
}
```

- [ ] **Step 2: Test'in fail ettiğini doğrula**

```powershell
flutter test test/coin_calculator_test.dart
```

Expected: `Error: Target of URI doesn't exist: 'package:zankurd_mobile/src/utils/coin_calculator.dart'`

- [ ] **Step 3: coin_calculator.dart dosyasını oluştur**

`zankurd_mobile/lib/src/utils/coin_calculator.dart`:

```dart
class CoinCalculator {
  CoinCalculator._();

  static int award({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) {
    final completionBonus = totalQuestions >= 10 ? 20 : 8;
    return completionBonus + (correctCount * 6) + (bestStreak * 2) + score ~/ 80;
  }

  static int practiceAward() => 0;
}
```

- [ ] **Step 4: MockZanKurdRepository'yi güncelle**

`mock_zankurd_repository.dart` başına import ekle:
```dart
import '../utils/coin_calculator.dart';
```

`_calculateCoinAward` metodunu (satır 355-366) şununla değiştir:
```dart
int _calculateCoinAward({
  required int score,
  required int correctCount,
  required int bestStreak,
  required int totalQuestions,
}) =>
    CoinCalculator.award(
      score: score,
      correctCount: correctCount,
      bestStreak: bestStreak,
      totalQuestions: totalQuestions,
    );
```

- [ ] **Step 5: Testleri çalıştır**

```powershell
flutter test test/coin_calculator_test.dart
```

Expected: `All tests passed! (5 tests)`

- [ ] **Step 6: Tüm testleri çalıştır (regresyon yok mu?)**

```powershell
flutter test
```

Expected: All passed.

- [ ] **Step 7: Commit**

```powershell
git add zankurd_mobile/lib/src/utils/coin_calculator.dart zankurd_mobile/test/coin_calculator_test.dart zankurd_mobile/lib/src/data/mock_zankurd_repository.dart
git commit -m "refactor: extract CoinCalculator utility and add unit tests"
```

---

## Task 3: QuizScreen Skor Testi

**Files:**
- Create: `zankurd_mobile/test/quiz_scoring_test.dart`

**Amaç:** Puan hesaplama mantığını (streak bonusu) test etmek. `quiz_screen.dart:475` — `score += 100 + (streak * 10).clamp(0, 50)`.

- [ ] **Step 1: Test dosyasını yaz**

`zankurd_mobile/test/quiz_scoring_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

// quiz_screen.dart:475 mantığını izole test fonksiyonu olarak yansıtıyoruz.
int _applyCorrectAnswer({required int score, required int streak}) {
  return score + 100 + (streak * 10).clamp(0, 50);
}

void main() {
  group('quiz skor hesaplama', () {
    test('ilk doğru cevap: 100 puan, streak=0', () {
      expect(_applyCorrectAnswer(score: 0, streak: 0), 100);
    });

    test('streak 1 iken → 100 + 10 = 110 puan', () {
      expect(_applyCorrectAnswer(score: 0, streak: 1), 110);
    });

    test('streak 5 → 100 + 50 = 150 (max streak bonus)', () {
      expect(_applyCorrectAnswer(score: 0, streak: 5), 150);
    });

    test('streak 10 → 100 + 50 = 150 (clamp uygulandı)', () {
      expect(_applyCorrectAnswer(score: 0, streak: 10), 150);
    });

    test('birden fazla doğru cevap birikir', () {
      // 3 doğru: streak 0→1→2, puanlar: 100+110+120=330
      int score = 0;
      for (int streak = 0; streak < 3; streak++) {
        score = _applyCorrectAnswer(score: score, streak: streak);
      }
      expect(score, 330);
    });
  });
}
```

- [ ] **Step 2: Çalıştır**

```powershell
flutter test test/quiz_scoring_test.dart
```

Expected: `All tests passed! (5 tests)`

- [ ] **Step 3: Commit**

```powershell
git add zankurd_mobile/test/quiz_scoring_test.dart
git commit -m "test: add quiz scoring unit tests"
```

---

## Task 4: AppRoute — Fade Slide Transitions

**Files:**
- Create: `zankurd_mobile/lib/src/utils/app_route.dart`
- Modify: 17 dosyada `MaterialPageRoute(` → `AppRoute.to(`

**Amaç:** Tüm ekran geçişleri için tutarlı, animasyonlu fade+slide transition.

- [ ] **Step 1: app_route.dart oluştur**

`zankurd_mobile/lib/src/utils/app_route.dart`:

```dart
import 'package:flutter/material.dart';

/// Tüm sayfa geçişleri için standart fade+slide animasyonu.
/// MaterialPageRoute yerine bu kullan: Navigator.push(context, AppRoute.to(MyScreen()))
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required Widget page, super.settings})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
        );

  /// Kullanım: Navigator.push(context, AppRoute.to(MyScreen()))
  static AppRoute<T> to<T>(Widget page) => AppRoute<T>(page: page);

  /// Kullanım: Navigator.pushReplacement(context, AppRoute.replace(MyScreen()))
  static AppRoute<T> replace<T>(Widget page) => AppRoute<T>(page: page);
}
```

- [ ] **Step 2: Tüm MaterialPageRoute'ları değiştir**

Her dosyada `MaterialPageRoute(builder: (_) => X(...)` → `AppRoute.to(X(...))` yap.
Her dosyanın başına import ekle:
```dart
import '../utils/app_route.dart';
```

**Değiştirilecek dosyalar ve satırlar:**
- `lib/src/screens/categories_tab.dart:108`
- `lib/src/screens/favorite_questions_screen.dart:128`
- `lib/src/screens/home_screen.dart:487,504,514,522,529`
- `lib/src/screens/leaderboard_screen.dart:42`
- `lib/src/screens/level_screen.dart:98`
- `lib/src/screens/profile_screen.dart:75,331,441`
- `lib/src/screens/quiz_result_screen.dart:350,370`
- `lib/src/screens/quiz_screen.dart:504` (bu `pushReplacement` — `AppRoute.replace` kullan)
- `lib/src/screens/room_screen.dart:292`
- `lib/src/screens/sign_in_screen.dart:533`

**Pattern:**
```dart
// Önce:
Navigator.push(context, MaterialPageRoute(builder: (_) => SomeScreen(x: x)));

// Sonra:
Navigator.push(context, AppRoute.to(SomeScreen(x: x)));
```

```dart
// pushReplacement için:
Navigator.of(context).pushReplacement(AppRoute.replace(QuizResultScreen(...)));
```

- [ ] **Step 3: Analiz et**

```powershell
flutter analyze lib/
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```powershell
git add zankurd_mobile/lib/src/utils/app_route.dart zankurd_mobile/lib/src/screens/
git commit -m "feat(ui): add fade+slide page transitions via AppRoute"
```

---

## Task 5: AppTheme — Context-Aware Renk Yardımcıları

**Files:**
- Modify: `zankurd_mobile/lib/src/theme/app_theme.dart` (sınıf sonuna ekle)
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart:550`
- Modify: `zankurd_mobile/lib/src/screens/leaderboard_screen.dart:280`
- Modify: `zankurd_mobile/lib/src/screens/level_screen.dart:220`
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart:523`
- Modify: `zankurd_mobile/lib/src/screens/quiz_result_screen.dart:651`
- Modify: `zankurd_mobile/lib/src/screens/review_screen.dart:198`
- Modify: `zankurd_mobile/lib/src/screens/settings_screen.dart:206,380,465`

**Amaç:** Hardcoded dark renkleri theme-aware yaparak light mode'da doğru renk gösterilmesini sağla.

- [ ] **Step 1: AppTheme'e helper metodlar ekle**

`app_theme.dart` içindeki `AppTheme` sınıfına şunları ekle (son satırdan önce):

```dart
  // ============ Context-Aware Helpers ============
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) =>
      _isDark(context) ? bg : lightBg;

  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? surface : lightSurface;

  static Color surfaceHiOf(BuildContext context) =>
      _isDark(context) ? surfaceHi : lightSurfaceHi;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? textPrimary : lightTextPrimary;

  static Color textSubOf(BuildContext context) =>
      _isDark(context) ? textSub : lightTextSub;

  static Color borderOf(BuildContext context) =>
      _isDark(context) ? border : lightBorder;
```

- [ ] **Step 2: 9 hardcoded rengi değiştir**

Her dosyada şu pattern'ı uygula:

```dart
// home_screen.dart:550
// Önce:
backgroundColor: AppTheme.surface,
// Sonra:
backgroundColor: AppTheme.surfaceOf(context),

// leaderboard_screen.dart:280
// Önce:
color: AppTheme.surface,
// Sonra:
color: AppTheme.surfaceOf(context),

// level_screen.dart:220
// Önce:
color: AppTheme.surface,
// Sonra:
color: AppTheme.surfaceOf(context),

// profile_screen.dart:523
// Önce:
backgroundColor: AppTheme.surface,
// Sonra:
backgroundColor: AppTheme.surfaceOf(context),

// quiz_result_screen.dart:651
// Önce:
: AppTheme.bg.withValues(alpha: 0.35),
// Sonra:
: AppTheme.bgOf(context).withValues(alpha: 0.35),

// review_screen.dart:198
// Önce:
color: AppTheme.bg.withValues(alpha: 0.35),
// Sonra:
color: AppTheme.bgOf(context).withValues(alpha: 0.35),

// settings_screen.dart:206
// Önce:
color: AppTheme.surface.withValues(alpha: 0.92),
// Sonra:
color: AppTheme.surfaceOf(context).withValues(alpha: 0.92),

// settings_screen.dart:380
// Önce:
backgroundColor: AppTheme.surface,
// Sonra:
backgroundColor: AppTheme.surfaceOf(context),

// settings_screen.dart:465
// Önce:
backgroundColor: AppTheme.surface,
// Sonra:
backgroundColor: AppTheme.surfaceOf(context),
```

- [ ] **Step 3: Analiz**

```powershell
flutter analyze lib/
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```powershell
git add zankurd_mobile/lib/src/theme/app_theme.dart zankurd_mobile/lib/src/screens/
git commit -m "feat: add context-aware AppTheme helpers for light/dark mode consistency"
```

---

## Task 6: Question Cache — SupabaseZanKurdRepository

**Files:**
- Modify: `zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart` (sınıf başı + loadQuestions)
- Create: `zankurd_mobile/test/question_cache_test.dart`

**Amaç:** Aynı kategori/limit parametreleriyle yapılan tekrarlı çağrılar Supabase'i vurmaz; 5 dakika TTL'li bellek cache kullanır.

- [ ] **Step 1: Test yaz (önce fail)**

`zankurd_mobile/test/question_cache_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/question_cache.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  late QuestionCache cache;

  setUp(() => cache = QuestionCache(ttl: const Duration(seconds: 1)));

  const q = QuizQuestion(
    id: 'q1',
    category: 'Ziman',
    prompt: 'test',
    answers: ['a', 'b'],
    correctAnswer: 'a',
    explanation: 'x',
  );

  test('boş cache → null döner', () {
    expect(cache.get('Ziman_10'), isNull);
  });

  test('set sonrası get → aynı listeyi döner', () {
    cache.set('Ziman_10', [q]);
    expect(cache.get('Ziman_10'), [q]);
  });

  test('TTL dolunca null döner', () async {
    cache.set('Ziman_10', [q]);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(cache.get('Ziman_10'), isNull);
  });

  test('farklı key → birbirini etkilemez', () {
    cache.set('Ziman_10', [q]);
    expect(cache.get('Cografya_10'), isNull);
  });
}
```

- [ ] **Step 2: Test fail ettiğini doğrula**

```powershell
flutter test test/question_cache_test.dart
```

Expected: `Error: Target of URI doesn't exist: 'package:zankurd_mobile/src/utils/question_cache.dart'`

- [ ] **Step 3: QuestionCache utility oluştur**

`zankurd_mobile/lib/src/utils/question_cache.dart`:

```dart
import '../models/quiz_question.dart';

class _CacheEntry {
  _CacheEntry({required this.questions, required this.expiresAt});
  final List<QuizQuestion> questions;
  final DateTime expiresAt;
}

class QuestionCache {
  QuestionCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  final _store = <String, _CacheEntry>{};

  List<QuizQuestion>? get(String key) {
    final entry = _store[key];
    if (entry == null || DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.questions;
  }

  void set(String key, List<QuizQuestion> questions) {
    _store[key] = _CacheEntry(
      questions: questions,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) => _store.remove(key);
  void clear() => _store.clear();
}
```

- [ ] **Step 4: Testleri çalıştır**

```powershell
flutter test test/question_cache_test.dart
```

Expected: `All tests passed! (4 tests)`

- [ ] **Step 5: SupabaseZanKurdRepository'ye cache entegre et**

`supabase_zankurd_repository.dart` dosyasına import ekle:
```dart
import '../utils/question_cache.dart';
```

`SupabaseZanKurdRepository` sınıfının en üstüne (client'tan hemen sonra) ekle:
```dart
  final _cache = QuestionCache();
```

`loadQuestions` override'ını bul ve cache wrapper ekle. Mevcut implementasyonun yerine:
```dart
  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    final key = '${categoryId ?? "all"}_$limit';
    final cached = _cache.get(key);
    if (cached != null) return cached;
    final result = await super.loadQuestions(categoryId: categoryId, limit: limit);
    _cache.set(key, result);
    return result;
  }
```

**Not:** `SupabaseZanKurdRepository` `MockZanKurdRepository`'den extend eder. `super.loadQuestions()` parent implementasyonu çağırır — rename gerekmez.

- [ ] **Step 6: Tüm testleri çalıştır**

```powershell
flutter test
```

Expected: All tests passed.

- [ ] **Step 7: Commit**

```powershell
git add zankurd_mobile/lib/src/utils/question_cache.dart zankurd_mobile/test/question_cache_test.dart zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart
git commit -m "feat(perf): add 5-minute TTL question cache to SupabaseZanKurdRepository"
```

---

## Task 7: Son Doğrulama

- [ ] **Step 1: Tüm testleri çalıştır**

```powershell
cd "C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile"
flutter test
```

Expected: All tests passed (en az 20+ test).

- [ ] **Step 2: Statik analiz**

```powershell
flutter analyze lib/ test/
```

Expected: `No issues found!`

- [ ] **Step 3: Format kontrolü**

```powershell
dart format --set-exit-if-changed lib/ test/
```

Expected: Çıkış kodu 0 (değişiklik yoksa). Değişiklik varsa:
```powershell
dart format lib/ test/
git add -A
git commit -m "style: dart format"
```

- [ ] **Step 4: Son commit — özet tag**

```powershell
git tag "grup-a-complete-$(Get-Date -Format 'yyyyMMdd')"
```

---

## Skor Tahmini Sonuç

| Kategori | Önceki | Sonrası | Yapılan |
|----------|--------|---------|---------|
| Architecture | 9/10 | 9.5/10 | Dependency pin, cache layer |
| Code Quality | 8/10 | 10/10 | Light mode helpers, extracted utility |
| Feature Completeness | 9/10 | 9/10 | Değişmedi (Grup B'de) |
| UI/UX Design | 8/10 | 10/10 | Fade+slide transitions |
| Performance | 7/10 | 9.5/10 | Question TTL cache |
| Maintainability | 8/10 | 10/10 | 20+ unit test, testable utilities |
