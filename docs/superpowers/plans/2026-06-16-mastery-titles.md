# Kategori Ustalık Unvanları Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Her kategoride doğru cevap sayısına dayalı 3 aşamalı ustalık unvanı sistemi ekle (Xwendekar/20, Pispor/100, Mamoste/400); quiz sonucunda terfi banner'ı, kategori kartlarında rozet ve profilde ilerleme çubuğu göster.

**Architecture:** `MasteryLevel` enum + `MasteryStore` (SharedPreferences singleton, AchievementStore kalıbı), her quiz sonrasında `quiz_result_screen.dart`'tan tetiklenir; `categories_tab.dart` ve `category_grid.dart` kartlarında küçük rozet, `profile_screen.dart`'ta tam ilerleme bölümü.

**Tech Stack:** Flutter/Dart 3, SharedPreferences, Provider, flutter_test + setMockInitialValues.

---

## Dosya Haritası

| İşlem | Dosya |
|-------|-------|
| Oluştur | `zankurd_mobile/lib/src/models/mastery_level.dart` |
| Oluştur | `zankurd_mobile/lib/src/data/mastery_store.dart` |
| Oluştur | `zankurd_mobile/test/mastery_store_test.dart` |
| Değiştir | `zankurd_mobile/lib/src/screens/quiz_result_screen.dart` |
| Değiştir | `zankurd_mobile/lib/src/screens/categories_tab.dart` |
| Değiştir | `zankurd_mobile/lib/src/screens/home/category_grid.dart` |
| Değiştir | `zankurd_mobile/lib/src/screens/profile_screen.dart` |

---

### Task 1: MasteryLevel modeli

**Files:**
- Create: `zankurd_mobile/lib/src/models/mastery_level.dart`

- [ ] **Step 1: Dosyayı oluştur**

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MasteryLevel { none, xwendekar, pispor, mamoste }

extension MasteryLevelDetails on MasteryLevel {
  static MasteryLevel fromCorrectCount(int count) {
    if (count >= 400) return MasteryLevel.mamoste;
    if (count >= 100) return MasteryLevel.pispor;
    if (count >= 20) return MasteryLevel.xwendekar;
    return MasteryLevel.none;
  }

  int get threshold => switch (this) {
    MasteryLevel.none => 0,
    MasteryLevel.xwendekar => 20,
    MasteryLevel.pispor => 100,
    MasteryLevel.mamoste => 400,
  };

  String get titleKu => switch (this) {
    MasteryLevel.none => '',
    MasteryLevel.xwendekar => 'Xwendekar',
    MasteryLevel.pispor => 'Pispor',
    MasteryLevel.mamoste => 'Mamoste',
  };

  String get titleTr => switch (this) {
    MasteryLevel.none => '',
    MasteryLevel.xwendekar => 'Öğrenci',
    MasteryLevel.pispor => 'Uzman',
    MasteryLevel.mamoste => 'Usta',
  };

  Color get badgeColor => switch (this) {
    MasteryLevel.none => AppTheme.textMuted,
    MasteryLevel.xwendekar => Colors.blue,
    MasteryLevel.pispor => Colors.purple,
    MasteryLevel.mamoste => AppTheme.gold,
  };

  IconData get icon => switch (this) {
    MasteryLevel.none => Icons.circle_outlined,
    MasteryLevel.xwendekar => Icons.school_outlined,
    MasteryLevel.pispor => Icons.psychology_outlined,
    MasteryLevel.mamoste => Icons.workspace_premium_outlined,
  };
}
```

- [ ] **Step 2: dart analyze çalıştır**

Konum: `zankurd_mobile/`
```
dart analyze lib/src/models/mastery_level.dart
```
Beklenen: No issues found (veya yalnızca uyarısız bilgi mesajları).

- [ ] **Step 3: Commit**

```
git add zankurd_mobile/lib/src/models/mastery_level.dart
git commit -m "feat(mastery): add MasteryLevel enum with thresholds, colors, icons"
```

---

### Task 2: MasteryStore testleri (önce başarısız)

**Files:**
- Create: `zankurd_mobile/test/mastery_store_test.dart`

- [ ] **Step 1: Test dosyasını yaz**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/models/mastery_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
  });

  group('MasteryLevelDetails.fromCorrectCount', () {
    test('0 → none', () => expect(
      MasteryLevelDetails.fromCorrectCount(0), MasteryLevel.none));
    test('19 → none', () => expect(
      MasteryLevelDetails.fromCorrectCount(19), MasteryLevel.none));
    test('20 → xwendekar', () => expect(
      MasteryLevelDetails.fromCorrectCount(20), MasteryLevel.xwendekar));
    test('99 → xwendekar', () => expect(
      MasteryLevelDetails.fromCorrectCount(99), MasteryLevel.xwendekar));
    test('100 → pispor', () => expect(
      MasteryLevelDetails.fromCorrectCount(100), MasteryLevel.pispor));
    test('399 → pispor', () => expect(
      MasteryLevelDetails.fromCorrectCount(399), MasteryLevel.pispor));
    test('400 → mamoste', () => expect(
      MasteryLevelDetails.fromCorrectCount(400), MasteryLevel.mamoste));
  });

  group('MasteryStore', () {
    test('yeni kategoride doğru sayısı 0 başlar', () async {
      final store = await MasteryStore.load();
      expect(store.correctCount('Ziman'), 0);
      expect(store.levelFor('Ziman'), MasteryLevel.none);
    });

    test('addCorrect kümülatif sayar', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 10);
      await store.addCorrect('Ziman', 5);
      expect(store.correctCount('Ziman'), 15);
    });

    test('addCorrect seviye atlamamışsa null döner', () async {
      final store = await MasteryStore.load();
      final result = await store.addCorrect('Ziman', 5);
      expect(result, isNull);
    });

    test('addCorrect xwendekar seviyesine atlayınca döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 15);
      final result = await store.addCorrect('Ziman', 10);
      expect(result, MasteryLevel.xwendekar);
    });

    test('addCorrect pispor seviyesine atlayınca döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 90);
      final result = await store.addCorrect('Ziman', 15);
      expect(result, MasteryLevel.pispor);
    });

    test('addCorrect mamoste seviyesine atlayınca döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 390);
      final result = await store.addCorrect('Ziman', 15);
      expect(result, MasteryLevel.mamoste);
    });

    test('addCorrect zaten mamoste ise null döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 400);
      final result = await store.addCorrect('Ziman', 10);
      expect(result, isNull);
    });

    test('farklı kategoriler bağımsız izlenir', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 25);
      await store.addCorrect('Çand', 5);
      expect(store.correctCount('Ziman'), 25);
      expect(store.correctCount('Çand'), 5);
      expect(store.levelFor('Ziman'), MasteryLevel.xwendekar);
      expect(store.levelFor('Çand'), MasteryLevel.none);
    });

    test('nextThreshold — 19 için 20 döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 19);
      expect(store.nextThreshold('Ziman'), 20);
    });

    test('nextThreshold — 25 için 100 döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 25);
      expect(store.nextThreshold('Ziman'), 100);
    });

    test('nextThreshold — 450 için 400 döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 450);
      expect(store.nextThreshold('Ziman'), 400);
    });

    test('resetInstance testler arası izolasyon sağlar', () async {
      final store1 = await MasteryStore.load();
      await store1.addCorrect('Ziman', 25);

      MasteryStore.resetInstance();
      SharedPreferences.setMockInitialValues({});

      final store2 = await MasteryStore.load();
      expect(store2.correctCount('Ziman'), 0);
    });
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Konum: `zankurd_mobile/`
```
flutter test test/mastery_store_test.dart
```
Beklenen: FAIL — `mastery_store.dart` henüz yok.

---

### Task 3: MasteryStore implementasyonu

**Files:**
- Create: `zankurd_mobile/lib/src/data/mastery_store.dart`

- [ ] **Step 1: Dosyayı oluştur**

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mastery_level.dart';

class MasteryStore {
  MasteryStore._(this._preferences);

  static const _keyPrefix = 'zankurd.mastery.';
  static MasteryStore? _instance;

  final SharedPreferences? _preferences;

  static Future<MasteryStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    return _instance = MasteryStore._(preferences);
  }

  static void resetInstance() => _instance = null;

  int correctCount(String category) =>
      _preferences?.getInt('$_keyPrefix$category') ?? 0;

  MasteryLevel levelFor(String category) =>
      MasteryLevelDetails.fromCorrectCount(correctCount(category));

  int nextThreshold(String category) {
    final count = correctCount(category);
    if (count < 20) return 20;
    if (count < 100) return 100;
    return 400;
  }

  Future<MasteryLevel?> addCorrect(String category, int count) async {
    if (count <= 0) return null;
    final before = levelFor(category);
    final newCount = correctCount(category) + count;
    await _preferences?.setInt('$_keyPrefix$category', newCount);
    final after = MasteryLevelDetails.fromCorrectCount(newCount);
    return after != before && after != MasteryLevel.none ? after : null;
  }
}
```

- [ ] **Step 2: Testleri çalıştır**

Konum: `zankurd_mobile/`
```
flutter test test/mastery_store_test.dart
```
Beklenen: All 15 tests pass.

- [ ] **Step 3: Tüm testleri çalıştır**

```
flutter test
```
Beklenen: Mevcut tüm testler + yeni 15 test geçer.

- [ ] **Step 4: Commit**

```
git add zankurd_mobile/lib/src/data/mastery_store.dart zankurd_mobile/test/mastery_store_test.dart
git commit -m "feat(mastery): add MasteryStore SharedPreferences singleton with 15 tests"
```

---

### Task 4: QuizResultScreen — mastery kaydı + terfi banner'ı

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz_result_screen.dart`

- [ ] **Step 1: Import satırlarını ekle (satır 1–16 arası, diğer import'larla birlikte)**

```dart
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
```

- [ ] **Step 2: `_QuizResultScreenState`'e `_promotions` alanı ekle (satır 69 civarı)**

`_newAchievements` tanımının hemen altına:
```dart
Map<String, MasteryLevel> _promotions = const {};
```

- [ ] **Step 3: `_recordProgress()` metodunu tamamen değiştir**

Mevcut metodu (satır 77–100) şununla değiştir:
```dart
Future<void> _recordProgress() async {
  final streakStore = await StreakStore.load();
  final streak = await streakStore.recordPlay();
  final mistakeStore = await MistakeStore.load();
  final achievementStore = await AchievementStore.load();
  final newAchievements = await achievementStore.recordQuizResult(
    category: room.category,
    totalQuestions: totalQuestions,
    correctCount: correctCount,
    bestStreak: bestStreak,
    dailyStreak: streak,
    userScore: score,
    practice: practice,
    dailyQuiz: dailyQuiz,
    remainingMistakes: mistakeStore.count,
    opponents: opponents,
  );

  final masteryStore = await MasteryStore.load();
  final correctByCategory = <String, int>{};
  for (final record in answerRecords) {
    if (record.isCorrect) {
      correctByCategory[record.category] =
          (correctByCategory[record.category] ?? 0) + 1;
    }
  }
  final promotions = <String, MasteryLevel>{};
  for (final entry in correctByCategory.entries) {
    final newLevel = await masteryStore.addCorrect(entry.key, entry.value);
    if (newLevel != null) promotions[entry.key] = newLevel;
  }

  if (mounted) {
    setState(() {
      _dailyStreak = streak;
      _newAchievements = newAchievements;
      _promotions = promotions;
    });
  }
}
```

- [ ] **Step 4: `build()` içinde terfi banner'larını ekle**

`if (_newAchievements.isNotEmpty)` bloğunun hemen **sonrasına** ekle (satır 210 civarı):
```dart
if (_promotions.isNotEmpty) ...[
  const SizedBox(height: 16),
  _MasteryPromotions(promotions: _promotions),
],
```

- [ ] **Step 5: `_MasteryPromotions` widget sınıfını dosyanın sonuna ekle**

`_RaceStandingRow` sınıfının sonuna (dosya sonu yakını), şu widget'ı ekle:
```dart
class _MasteryPromotions extends StatelessWidget {
  const _MasteryPromotions({required this.promotions});

  final Map<String, MasteryLevel> promotions;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Column(
      children: [
        for (final entry in promotions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppPanel(
              color: entry.value.badgeColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.value.badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(entry.value.icon, color: entry.value.badgeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku
                              ? '${CategoryNames.localized(entry.key, true)} — ${entry.value.titleKu}!'
                              : '${CategoryNames.localized(entry.key, false)} — ${entry.value.titleTr}!',
                          style: TextStyle(
                            color: entry.value.badgeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          ku ? 'Unvana nû stend!' : 'Yeni unvan kazandın!',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: dart analyze çalıştır**

Konum: `zankurd_mobile/`
```
dart analyze lib/src/screens/quiz_result_screen.dart
```
Beklenen: No issues found.

- [ ] **Step 7: Commit**

```
git add zankurd_mobile/lib/src/screens/quiz_result_screen.dart
git commit -m "feat(mastery): record mastery per quiz; show promotion banner on result screen"
```

---

### Task 5: CategoriesTab — kategori kartlarında mastery rozeti

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/categories_tab.dart`

- [ ] **Step 1: Import ekle**

Dosyanın üstüne, diğer data importlarıyla birlikte:
```dart
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
```

- [ ] **Step 2: `_CategoriesTabState`'e alan ekle**

`_loading` alanının yanına:
```dart
Map<String, MasteryLevel> _masteryLevels = {};
```

- [ ] **Step 3: `_load()` metodunu değiştir**

Mevcut `_load()`:
```dart
Future<void> _load() async {
  setState(() => _loading = true);
  try {
    final cats = await widget.repository.loadCategories();
    if (mounted && cats.isNotEmpty) setState(() => _categories = cats);
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'categories load failed');
  }
  if (mounted) setState(() => _loading = false);
}
```

Şununla değiştir:
```dart
Future<void> _load() async {
  setState(() => _loading = true);
  try {
    final cats = await widget.repository.loadCategories();
    if (mounted && cats.isNotEmpty) setState(() => _categories = cats);
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'categories load failed');
  }
  if (mounted) setState(() => _loading = false);
  await _loadMastery();
}

Future<void> _loadMastery() async {
  final store = await MasteryStore.load();
  if (!mounted) return;
  final levels = <String, MasteryLevel>{};
  for (final cat in _categories) {
    levels[cat] = store.levelFor(cat);
  }
  setState(() => _masteryLevels = levels);
}
```

- [ ] **Step 4: `itemBuilder`'da `masteryLevel` geçir**

`build()` içindeki `itemBuilder` callback'ini şununla değiştir:
```dart
itemBuilder: (context, index) {
  final cat = _categories[index];
  return _CategoryCard(
    category: cat,
    index: index,
    isKu: ku,
    masteryLevel: _masteryLevels[cat] ?? MasteryLevel.none,
    onTap: () => Navigator.of(context).push(
      AppRoute.to(
        LevelScreen(
          repository: widget.repository,
          category: cat,
        ),
      ),
    ),
  );
},
```

- [ ] **Step 5: `_CategoryCard`'a `masteryLevel` parametresi ekle**

`_CategoryCard` constructor'ını şununla değiştir:
```dart
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isKu,
    required this.masteryLevel,
    required this.onTap,
  });

  final String category;
  final int index;
  final bool isKu;
  final MasteryLevel masteryLevel;
  final VoidCallback onTap;
```

- [ ] **Step 6: `_CategoryCard.build()` içine rozet ekle**

`build()` metodunun `Column` children listesinde "5 ast · pêşbaz" Container'ının hemen **sonrasına** şunu ekle:
```dart
if (masteryLevel != MasteryLevel.none) ...[
  const SizedBox(height: 4),
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        masteryLevel.icon,
        color: Colors.white.withValues(alpha: 0.9),
        size: 11,
      ),
      const SizedBox(width: 3),
      Text(
        isKu ? masteryLevel.titleKu : masteryLevel.titleTr,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
],
```

- [ ] **Step 7: dart analyze çalıştır**

```
dart analyze lib/src/screens/categories_tab.dart
```
Beklenen: No issues found.

- [ ] **Step 8: Commit**

```
git add zankurd_mobile/lib/src/screens/categories_tab.dart
git commit -m "feat(mastery): show mastery badge on category cards in CategoriesTab"
```

---

### Task 6: CategoryGrid (home screen) — mastery rozeti

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home/category_grid.dart`

- [ ] **Step 1: Import ekle**

```dart
import '../../data/mastery_store.dart';
import '../../models/mastery_level.dart';
```

- [ ] **Step 2: `CategoryGrid`'i `StatelessWidget`'tan `StatefulWidget`'a dönüştür**

Mevcut sınıf tanımını tamamen şununla değiştir:
```dart
class CategoryGrid extends StatefulWidget {
  const CategoryGrid({
    required this.categories,
    required this.isKu,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final List<String> categories;
  final bool isKu;
  final bool loading;
  final ValueChanged<String> onTap;

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  Map<String, MasteryLevel> _masteryLevels = {};

  @override
  void initState() {
    super.initState();
    _loadMastery();
  }

  Future<void> _loadMastery() async {
    final store = await MasteryStore.load();
    if (!mounted) return;
    final levels = <String, MasteryLevel>{};
    for (final cat in widget.categories) {
      levels[cat] = store.levelFor(cat);
    }
    setState(() => _masteryLevels = levels);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return GridView.builder(
      itemCount: widget.categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final cat = widget.categories[index];
        return _CategoryCard(
          category: cat,
          index: index,
          isKu: widget.isKu,
          masteryLevel: _masteryLevels[cat] ?? MasteryLevel.none,
          onTap: () => widget.onTap(cat),
        );
      },
    );
  }
}
```

- [ ] **Step 3: `_CategoryCard`'a `masteryLevel` parametresi ekle**

Mevcut `_CategoryCard` class tanımını şununla değiştir:
```dart
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isKu,
    required this.masteryLevel,
    required this.onTap,
  });

  final String category;
  final int index;
  final bool isKu;
  final MasteryLevel masteryLevel;
  final VoidCallback onTap;
```

- [ ] **Step 4: `build()` içine rozet ekle**

"5 ast · pêşbaz" `Text` widget'ının (`SizedBox(height: 3)` sonrası) hemen altına:
```dart
if (masteryLevel != MasteryLevel.none) ...[
  const SizedBox(height: 2),
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        masteryLevel.icon,
        color: Colors.white.withValues(alpha: 0.85),
        size: 10,
      ),
      const SizedBox(width: 3),
      Text(
        isKu ? masteryLevel.titleKu : masteryLevel.titleTr,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
],
```

- [ ] **Step 5: dart analyze çalıştır**

```
dart analyze lib/src/screens/home/category_grid.dart
```
Beklenen: No issues found.

- [ ] **Step 6: Commit**

```
git add zankurd_mobile/lib/src/screens/home/category_grid.dart
git commit -m "feat(mastery): show mastery badge on home screen CategoryGrid cards"
```

---

### Task 7: ProfileScreen — Kategori Ustalığı bölümü

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart`

- [ ] **Step 1: Import ekle**

Dosyanın üstüne:
```dart
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
```

- [ ] **Step 2: `_ProfileScreenState`'e alan ekle**

`_achievements` alanının hemen altına:
```dart
MasteryStore? _masteryStore;
```

- [ ] **Step 3: `_load()` içine MasteryStore yüklemesini ekle**

`achievementStore.unlockedAchievements` atamasından sonra, `if (mounted)` bloğunun içindeki setState'e `_masteryStore = masteryStore` ekle.

Mevcut `_load()` try bloğu:
```dart
final name = await widget.repository.getProfileName();
final stats = await widget.repository.getPlayerStats();
final achievementStore = await AchievementStore.load();
if (mounted) {
  setState(() {
    _currentName = name;
    _stats = stats;
    _achievements = achievementStore.unlockedAchievements;
    _loading = false;
    _loadFailed = false;
  });
}
```

Şununla değiştir:
```dart
final name = await widget.repository.getProfileName();
final stats = await widget.repository.getPlayerStats();
final achievementStore = await AchievementStore.load();
final masteryStore = await MasteryStore.load();
if (mounted) {
  setState(() {
    _currentName = name;
    _stats = stats;
    _achievements = achievementStore.unlockedAchievements;
    _masteryStore = masteryStore;
    _loading = false;
    _loadFailed = false;
  });
}
```

- [ ] **Step 4: `build()` içinde `_AchievementShowcase`'den sonra `_MasterySection` ekle**

Mevcut (satır 322 civarı):
```dart
_AchievementShowcase(achievements: _achievements, isKu: ku),
const SizedBox(height: 14),
```

Şununla değiştir:
```dart
_AchievementShowcase(achievements: _achievements, isKu: ku),
const SizedBox(height: 14),
if (_masteryStore != null) ...[
  _MasterySection(store: _masteryStore!, isKu: ku),
  const SizedBox(height: 14),
],
```

- [ ] **Step 5: `_MasterySection` ve `_MasteryRow` sınıflarını dosyanın sonuna ekle**

`_AchievementChip` sınıfının sonuna şunu ekle:
```dart
class _MasterySection extends StatelessWidget {
  const _MasterySection({required this.store, required this.isKu});

  final MasteryStore store;
  final bool isKu;

  static const _categories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
  ];

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppTheme.violet,
              ),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Ustalîya Kategoriyê' : 'Kategori Ustalığı',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final cat in _categories)
            _MasteryRow(category: cat, store: store, isKu: isKu),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.category,
    required this.store,
    required this.isKu,
  });

  final String category;
  final MasteryStore store;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final level = store.levelFor(category);
    final count = store.correctCount(category);
    final threshold = store.nextThreshold(category);
    final isMamoste = level == MasteryLevel.mamoste;
    final progress =
        isMamoste ? 1.0 : (count / threshold).clamp(0.0, 1.0);
    final badgeColor =
        level == MasteryLevel.none ? AppTheme.textMuted : level.badgeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              CategoryNames.localized(category, isKu),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              level == MasteryLevel.none
                  ? (isKu ? 'Destpêkirin' : 'Başlangıç')
                  : (isKu ? level.titleKu : level.titleTr),
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMamoste ? '✓' : '$count/$threshold',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: dart analyze çalıştır**

```
dart analyze lib/src/screens/profile_screen.dart
```
Beklenen: No issues found.

- [ ] **Step 7: Commit**

```
git add zankurd_mobile/lib/src/screens/profile_screen.dart
git commit -m "feat(mastery): add Kategori Ustalığı section to profile screen"
```

---

### Task 8: Final doğrulama

**Files:** (değişiklik yok)

- [ ] **Step 1: Tüm testleri çalıştır**

Konum: `zankurd_mobile/`
```
flutter test
```
Beklenen: 130+ test pass (116 mevcut + 15 yeni mastery testi).

- [ ] **Step 2: Projeyi analiz et**

```
dart analyze
```
Beklenen: No issues found.

- [ ] **Step 3: Final commit**

```
git add -A
git commit -m "feat(mastery): complete Kategori Ustalık Unvanları system"
```
