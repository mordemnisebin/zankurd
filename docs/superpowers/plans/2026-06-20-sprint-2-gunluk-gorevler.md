# Sprint 2 — Günlük Görev Sistemi (Daily Mission System) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Her gün 3 görev üret (gün tohumlu, deterministik), kullanıcı quiz oynarken ilerlesin, tamamlanınca coin ödülü al ve özel bir toast ile bildirilsin; HomeScreen'de DailyMissionsCard ile ilerleme görünsün.

**Architecture:** `DailyMission` model + `MissionDefinitions` havuzu → `DailyMissionStore` (SharedPreferences singleton, mevcut pattern) → `DailyMissionsCard` (StatelessWidget, veri HomeScreen'den) → progress hook'ları `quiz_result_screen.dart` ve `quiz_screen.dart`'ta.

**Tech Stack:** Flutter 3.x, SharedPreferences, `dart:math.Random` (tohumlu), `ScaffoldMessenger` (styled SnackBar olarak toast), repository pattern (mevcut)

**Critical constraints:**
- `dart analyze` kullan — `flutter analyze` ÇALIŞMAZ (C:\Users\AMARGİ\... yolundaki Türkçe İ harfi LSP'yi bozuyor)
- Test komutu: `cd zankurd_mobile && flutter test`
- Build gerektiren hiçbir görev yok; tüm görevler analyze + test ile doğrulanır

---

## File Map

**Yeni dosyalar:**
- `zankurd_mobile/lib/src/models/daily_mission.dart` — `MissionType` enum, `DailyMission` sınıfı, `MissionDefinitions` havuzu, `_MissionDef` yardımcı sınıf
- `zankurd_mobile/lib/src/data/daily_mission_store.dart` — Günlük görev singleton store
- `zankurd_mobile/lib/src/screens/home/daily_missions_card.dart` — HomeScreen için görev kartı widget'ı
- `zankurd_mobile/lib/src/widgets/mission_toast.dart` — Görev tamamlama toast yardımcısı
- `zankurd_mobile/supabase/award_coins.sql` — Supabase coin ödül RPC
- `zankurd_mobile/test/daily_mission_store_test.dart` — 8 unit test

**Değiştirilen dosyalar:**
- `zankurd_mobile/lib/src/data/zankurd_repository.dart` — `addCoins` abstract metod
- `zankurd_mobile/lib/src/data/mock_zankurd_repository.dart` — `addCoins` implementasyonu
- `zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart` — `addCoins` implementasyonu
- `zankurd_mobile/lib/src/screens/home_screen.dart` — missions yükle, DailyMissionsCard ekle, quiz dönüşünde refresh
- `zankurd_mobile/lib/src/screens/quiz_result_screen.dart` — `_recordProgress`'e mission hook
- `zankurd_mobile/lib/src/screens/quiz_screen.dart` — 4 wildcard metoduna mission hook

---

## Task 1: DailyMission Model + MissionDefinitions

**Files:**
- Create: `zankurd_mobile/lib/src/models/daily_mission.dart`

- [ ] **Step 1: Dosyayı oluştur**

```dart
// zankurd_mobile/lib/src/models/daily_mission.dart
import 'dart:math';

enum MissionType {
  answerCorrect,
  completeQuiz,
  useWildcard,
  keepStreak,
  playCategory,
}

class DailyMission {
  DailyMission({
    required this.type,
    required this.target,
    required this.coinReward,
    this.category,
    this.progress = 0,
    this.completed = false,
  });

  final MissionType type;
  final int target;
  final int coinReward;
  final String? category;
  int progress;
  bool completed;

  String get labelKu => switch (type) {
        MissionType.answerCorrect => '$target bersivên rast bide',
        MissionType.completeQuiz => '$target pêşbirk biqedîne',
        MissionType.useWildcard => '$target joker bikar bîne',
        MissionType.keepStreak => 'Seriya xwe biparêze',
        MissionType.playCategory => 'Di ${category ?? ''} de bilîze',
      };

  String get labelTr => switch (type) {
        MissionType.answerCorrect => '$target doğru cevap ver',
        MissionType.completeQuiz => '$target quiz tamamla',
        MissionType.useWildcard => '$target joker kullan',
        MissionType.keepStreak => 'Serisini koru',
        MissionType.playCategory => '${category ?? ''} kategorisinde oyna',
      };
}

class _MissionDef {
  const _MissionDef({
    required this.type,
    required this.target,
    required this.coinReward,
    this.category,
  });

  final MissionType type;
  final int target;
  final int coinReward;
  final String? category;
}

class MissionDefinitions {
  static const List<_MissionDef> pool = [
    _MissionDef(type: MissionType.answerCorrect, target: 5, coinReward: 30),
    _MissionDef(type: MissionType.answerCorrect, target: 10, coinReward: 50),
    _MissionDef(type: MissionType.answerCorrect, target: 15, coinReward: 75),
    _MissionDef(type: MissionType.completeQuiz, target: 1, coinReward: 25),
    _MissionDef(type: MissionType.completeQuiz, target: 3, coinReward: 60),
    _MissionDef(type: MissionType.useWildcard, target: 1, coinReward: 20),
    _MissionDef(type: MissionType.useWildcard, target: 2, coinReward: 40),
    _MissionDef(type: MissionType.keepStreak, target: 1, coinReward: 30),
    _MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Ziman',
    ),
    _MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Çand',
    ),
    _MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Dîrok',
    ),
    _MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Edebiyat',
    ),
    _MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Cografya',
    ),
    _MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Muzîk',
    ),
  ];

  /// Verilen gün tohumundan 3 görev üretir. Aynı gün = aynı 3 görev.
  static List<DailyMission> forDay(DateTime day) {
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final rng = Random(seed);
    final shuffled = List<_MissionDef>.from(pool)..shuffle(rng);
    return shuffled
        .take(3)
        .map(
          (def) => DailyMission(
            type: def.type,
            target: def.target,
            coinReward: def.coinReward,
            category: def.category,
          ),
        )
        .toList();
  }
}
```

- [ ] **Step 2: Dart analyzer ile doğrula**

```powershell
cd zankurd_mobile
dart analyze lib/src/models/daily_mission.dart
```

Beklenen: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add zankurd_mobile/lib/src/models/daily_mission.dart
git commit -m "feat(missions): add DailyMission model and MissionDefinitions pool"
```

---

## Task 2: DailyMissionStore TDD

**Files:**
- Create: `zankurd_mobile/lib/src/data/daily_mission_store.dart`
- Create: `zankurd_mobile/test/daily_mission_store_test.dart`

- [ ] **Step 1: Test dosyasını yaz (önce fail edecek)**

```dart
// zankurd_mobile/test/daily_mission_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DailyMissionStore.resetInstance();
  });

  test('load returns 3 missions', () async {
    final store = await DailyMissionStore.load();
    expect(store.missions.length, 3);
  });

  test('same day yields identical mission types', () async {
    final store1 = await DailyMissionStore.load();
    final types1 = store1.missions.map((m) => m.type).toList();
    DailyMissionStore.resetInstance();
    final store2 = await DailyMissionStore.load();
    final types2 = store2.missions.map((m) => m.type).toList();
    expect(types1, equals(types2));
  });

  test('reportQuizCompleted increments answerCorrect progress', () async {
    final missions = [
      DailyMission(type: MissionType.answerCorrect, target: 10, coinReward: 50),
      DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
      DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    await store.reportQuizCompleted(
      correctAnswers: 4,
      category: 'Ziman',
      streakAlive: false,
    );
    expect(missions[0].progress, 4);
  });

  test('reportQuizCompleted completes quiz mission immediately', () async {
    final missions = [
      DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25),
      DailyMission(type: MissionType.answerCorrect, target: 10, coinReward: 50),
      DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    final completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Ziman',
      streakAlive: false,
    );
    expect(missions[0].completed, isTrue);
    expect(completed.length, 1);
    expect(completed.first.type, MissionType.completeQuiz);
  });

  test('reportQuizCompleted completes keepStreak when streak is alive', () async {
    final missions = [
      DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
      DailyMission(type: MissionType.answerCorrect, target: 10, coinReward: 50),
      DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    final completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Ziman',
      streakAlive: true,
    );
    expect(missions[0].completed, isTrue);
    expect(completed.any((m) => m.type == MissionType.keepStreak), isTrue);
  });

  test('reportWildcardUsed increments and completes at target', () async {
    final missions = [
      DailyMission(type: MissionType.useWildcard, target: 2, coinReward: 40),
      DailyMission(type: MissionType.answerCorrect, target: 5, coinReward: 30),
      DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    final first = await store.reportWildcardUsed();
    expect(missions[0].progress, 1);
    expect(first, isNull);
    final second = await store.reportWildcardUsed();
    expect(missions[0].progress, 2);
    expect(second, isNotNull);
    expect(second!.type, MissionType.useWildcard);
    expect(missions[0].completed, isTrue);
  });

  test('already completed missions are skipped in subsequent reports', () async {
    final missions = [
      DailyMission(
        type: MissionType.completeQuiz,
        target: 1,
        coinReward: 25,
        completed: true,
        progress: 1,
      ),
      DailyMission(type: MissionType.answerCorrect, target: 5, coinReward: 30),
      DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    final completed = await store.reportQuizCompleted(
      correctAnswers: 5,
      category: 'Ziman',
      streakAlive: true,
    );
    // completeQuiz already completed — must NOT appear again
    expect(completed.any((m) => m.type == MissionType.completeQuiz), isFalse);
  });

  test('stale date resets progress', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zankurd.missions.date', '1999-01-01');
    await prefs.setStringList('zankurd.missions.progress', ['5', '5', '5']);
    await prefs.setStringList(
      'zankurd.missions.completed',
      ['true', 'true', 'true'],
    );
    DailyMissionStore.resetInstance();
    final store = await DailyMissionStore.load();
    expect(store.missions.every((m) => m.progress == 0 && !m.completed), isTrue);
  });

  test('playCategory mission completes only when category matches', () async {
    final missions = [
      DailyMission(
        type: MissionType.playCategory,
        target: 1,
        coinReward: 25,
        category: 'Ziman',
      ),
      DailyMission(type: MissionType.answerCorrect, target: 5, coinReward: 30),
      DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
    ];
    final store = await DailyMissionStore.loadForTest(missions);

    // Wrong category — no completion
    var completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Muzîk',
      streakAlive: false,
    );
    expect(completed.any((m) => m.type == MissionType.playCategory), isFalse);

    // Correct category — completes
    completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Ziman',
      streakAlive: false,
    );
    expect(completed.any((m) => m.type == MissionType.playCategory), isTrue);
  });
}
```

- [ ] **Step 2: Test'i çalıştır, fail ettiğini doğrula**

```powershell
cd zankurd_mobile
flutter test test/daily_mission_store_test.dart
```

Beklenen: `Error: Could not find package 'zankurd_mobile'` veya import hatası — store henüz yok.

- [ ] **Step 3: Store'u uygula**

```dart
// zankurd_mobile/lib/src/data/daily_mission_store.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mission.dart';

class DailyMissionStore {
  DailyMissionStore._(this._prefs, this._missions);

  static const _dateKey = 'zankurd.missions.date';
  static const _progressKey = 'zankurd.missions.progress';
  static const _completedKey = 'zankurd.missions.completed';

  static DailyMissionStore? _instance;

  final SharedPreferences? _prefs;
  final List<DailyMission> _missions;

  List<DailyMission> get missions => List.unmodifiable(_missions);

  static String _dateString(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static Future<DailyMissionStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    final today = DateTime.now();
    final todayKey = _dateString(today);
    final storedDate = prefs?.getString(_dateKey);
    final missions = MissionDefinitions.forDay(today);

    if (storedDate == todayKey) {
      final progressList = prefs?.getStringList(_progressKey) ?? [];
      final completedList = prefs?.getStringList(_completedKey) ?? [];
      for (var i = 0; i < missions.length; i++) {
        if (i < progressList.length) {
          missions[i].progress = int.tryParse(progressList[i]) ?? 0;
        }
        if (i < completedList.length) {
          missions[i].completed = completedList[i] == 'true';
        }
      }
    }

    return _instance = DailyMissionStore._(prefs, missions);
  }

  /// Yalnızca test'lerde kullanılır — belirli görevlerle store yükler.
  @visibleForTesting
  static Future<DailyMissionStore> loadForTest(
    List<DailyMission> missions,
  ) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return _instance = DailyMissionStore._(prefs, missions);
  }

  static void resetInstance() => _instance = null;

  /// Quiz tamamlandığında çağrılır. Yeni tamamlanan görevler döner.
  Future<List<DailyMission>> reportQuizCompleted({
    required int correctAnswers,
    required String category,
    required bool streakAlive,
  }) async {
    final completed = <DailyMission>[];
    for (final mission in _missions) {
      if (mission.completed) continue;
      switch (mission.type) {
        case MissionType.answerCorrect:
          mission.progress =
              (mission.progress + correctAnswers).clamp(0, mission.target);
        case MissionType.completeQuiz:
          mission.progress =
              (mission.progress + 1).clamp(0, mission.target);
        case MissionType.keepStreak:
          if (streakAlive) mission.progress = mission.target;
        case MissionType.playCategory:
          if (category == mission.category) mission.progress = mission.target;
        case MissionType.useWildcard:
          break;
      }
      if (!mission.completed && mission.progress >= mission.target) {
        mission.completed = true;
        completed.add(mission);
      }
    }
    await _persist();
    return completed;
  }

  /// Joker kullanıldığında çağrılır. Tamamlanan görev döner (null = henüz tamamlanmadı).
  Future<DailyMission?> reportWildcardUsed() async {
    for (final mission in _missions) {
      if (mission.completed) continue;
      if (mission.type != MissionType.useWildcard) continue;
      mission.progress = (mission.progress + 1).clamp(0, mission.target);
      if (mission.progress >= mission.target) {
        mission.completed = true;
        await _persist();
        return mission;
      }
      await _persist();
      return null;
    }
    return null;
  }

  Future<void> _persist() async {
    final today = _dateString(DateTime.now());
    await _prefs?.setString(_dateKey, today);
    await _prefs?.setStringList(
      _progressKey,
      _missions.map((m) => m.progress.toString()).toList(),
    );
    await _prefs?.setStringList(
      _completedKey,
      _missions.map((m) => m.completed.toString()).toList(),
    );
  }
}
```

- [ ] **Step 4: Testleri çalıştır, geçtiğini doğrula**

```powershell
cd zankurd_mobile
flutter test test/daily_mission_store_test.dart --reporter=compact
```

Beklenen: `8 tests passed.`

- [ ] **Step 5: Tüm test suite'i çalıştır**

```powershell
flutter test --reporter=compact
```

Beklenen: Önceki sayı + 8 yeni test, hepsi yeşil.

- [ ] **Step 6: Commit**

```powershell
git add zankurd_mobile/lib/src/data/daily_mission_store.dart
git add zankurd_mobile/test/daily_mission_store_test.dart
git commit -m "feat(missions): DailyMissionStore TDD — 8 tests"
```

---

## Task 3: addCoins Repository Metodu

**Files:**
- Modify: `zankurd_mobile/lib/src/data/zankurd_repository.dart`
- Modify: `zankurd_mobile/lib/src/data/mock_zankurd_repository.dart`
- Modify: `zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart`
- Create: `zankurd_mobile/supabase/award_coins.sql`

- [ ] **Step 1: Abstract interface'e metod ekle**

`zankurd_repository.dart`'ta `spendCoins` metodunun hemen altına ekle:

```dart
  /// Oyuncunun coin bakiyesine [amount] kadar ekler (görev ödülü vb.).
  Future<void> addCoins(int amount, String reason);
```

- [ ] **Step 2: Mock implementasyonunu ekle**

`mock_zankurd_repository.dart`'ta `spendCoins` metodunun hemen altına ekle:

```dart
  @override
  Future<void> addCoins(int amount, String reason) async {
    if (amount > 0) _mockCoins += amount;
  }
```

- [ ] **Step 3: SQL RPC dosyasını oluştur**

```sql
-- zankurd_mobile/supabase/award_coins.sql
-- Oyuncunun coin bakiyesine pozitif işlem ekler (görev ödülleri için).
create or replace function public.award_coins(p_amount integer, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  if p_amount <= 0 then return; end if;

  insert into coin_transactions (player_id, amount, reason)
  values (v_uid, p_amount, p_reason);
end;
$$;
```

- [ ] **Step 4: Supabase implementasyonunu ekle**

`supabase_zankurd_repository.dart`'ta `spendCoins` metodunun hemen altına ekle:

```dart
  @override
  Future<void> addCoins(int amount, String reason) async {
    if (amount <= 0) return;
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      await client.rpc(
        'award_coins',
        params: {'p_amount': amount, 'p_reason': reason},
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'addCoins failed');
    }
  }
```

- [ ] **Step 5: Analyzer ile doğrula**

```powershell
cd zankurd_mobile
dart analyze lib/src/data/
```

Beklenen: `No issues found!`

- [ ] **Step 6: Testleri çalıştır**

```powershell
flutter test --reporter=compact
```

Beklenen: Tüm testler yeşil (sayı değişmez — addCoins için ayrı test yok, mock'ta `_mockCoins` artar).

- [ ] **Step 7: Commit**

```powershell
git add zankurd_mobile/lib/src/data/zankurd_repository.dart
git add zankurd_mobile/lib/src/data/mock_zankurd_repository.dart
git add zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart
git add zankurd_mobile/supabase/award_coins.sql
git commit -m "feat(repo): add addCoins method + award_coins SQL RPC"
```

---

## Task 4: DailyMissionsCard Widget + MissionToast

**Files:**
- Create: `zankurd_mobile/lib/src/screens/home/daily_missions_card.dart`
- Create: `zankurd_mobile/lib/src/widgets/mission_toast.dart`

- [ ] **Step 1: MissionToast helper'ını oluştur**

```dart
// zankurd_mobile/lib/src/widgets/mission_toast.dart
import 'package:flutter/material.dart';

import '../models/daily_mission.dart';
import '../theme/app_theme.dart';
import '../l10n/lang.dart';

class MissionToast {
  static void show(BuildContext context, DailyMission mission) {
    if (!context.mounted) return;
    final isKu = context.isKu;
    final label = isKu ? mission.labelKu : mission.labelTr;
    final message = isKu
        ? '$label — +${mission.coinReward} coin!'
        : '$label — +${mission.coinReward} coin!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKu ? 'Erkek pêkhat!' : 'Görev tamamlandı!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
        backgroundColor: AppTheme.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
```

- [ ] **Step 2: DailyMissionsCard widget'ını oluştur**

```dart
// zankurd_mobile/lib/src/screens/home/daily_missions_card.dart
import 'package:flutter/material.dart';

import '../../models/daily_mission.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/skeleton_loader.dart';

class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({
    required this.isKu,
    required this.missions,
    this.loading = false,
    super.key,
  });

  final bool isKu;
  final List<DailyMission> missions;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Erkên Rojane' : 'Günlük Görevler',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                loading
                    ? ''
                    : '${missions.where((m) => m.completed).length}/${missions.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const SkeletonLoader(count: 3, height: 48, borderRadius: 8)
          else
            ...missions.map((m) => _MissionTile(mission: m, isKu: isKu)),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission, required this.isKu});

  final DailyMission mission;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final ratio = (mission.progress / mission.target).clamp(0.0, 1.0);
    final label = isKu ? mission.labelKu : mission.labelTr;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mission.completed
                        ? AppTheme.gold
                        : Theme.of(context).colorScheme.onSurface,
                    decoration:
                        mission.completed ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.gold,
                  ),
                ),
              ),
              if (mission.completed)
                Icon(Icons.check_circle_rounded, color: AppTheme.gold, size: 16)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: AppTheme.gold,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+${mission.coinReward}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: mission.completed ? AppTheme.gold : AppTheme.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${mission.progress.clamp(0, mission.target)} / ${mission.target}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

**Not:** `AppTheme.primary` ve `AppTheme.gold` mevcut proje tema sabitlerinden alınır (`lib/src/theme/app_theme.dart`). `AppPanel` `lib/src/widgets/app_panel.dart`'ta mevcut.

- [ ] **Step 3: Analyzer ile doğrula**

```powershell
cd zankurd_mobile
dart analyze lib/src/screens/home/daily_missions_card.dart lib/src/widgets/mission_toast.dart
```

Beklenen: `No issues found!`

- [ ] **Step 4: Commit**

```powershell
git add zankurd_mobile/lib/src/screens/home/daily_missions_card.dart
git add zankurd_mobile/lib/src/widgets/mission_toast.dart
git commit -m "feat(missions): DailyMissionsCard widget + MissionToast"
```

---

## Task 5: HomeScreen Entegrasyonu

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart`

HomeScreen'de şu değişiklikler gerekiyor:
1. `_missions` ve `_missionsLoading` state variable'ları ekle
2. `_loadMissions()` metodu ekle — `DailyMissionStore.load()` çağırır
3. `initState`'te `_loadMissions()` çağır
4. `_openQuiz` ve `_openDailyQuiz` await'lerinden sonra `_loadMissions()` çağır
5. SliverList index 4'ü (şu an `SizedBox.shrink()`) `DailyMissionsCard` ile değiştir
6. Import'ları ekle

- [ ] **Step 1: Import'ları ekle**

`home_screen.dart` dosyasındaki mevcut import'ların altına ekle:

```dart
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'home/daily_missions_card.dart';
```

- [ ] **Step 2: State variable'ları ekle**

`_HomeScreenState`'te mevcut `int _streak = 0;` satırının altına ekle:

```dart
  List<DailyMission> _missions = [];
  bool _missionsLoading = true;
```

- [ ] **Step 3: `_loadMissions` metodunu ekle**

`_refreshCoins` metodunun hemen üstüne ekle:

```dart
  Future<void> _loadMissions() async {
    final store = await DailyMissionStore.load();
    if (mounted) {
      setState(() {
        _missions = store.missions;
        _missionsLoading = false;
      });
    }
  }
```

- [ ] **Step 4: initState'te çağır**

`_HomeScreenState.initState()`'te `_refreshStreak();` satırının altına ekle:

```dart
    _loadMissions();
```

- [ ] **Step 5: Quiz dönüşünde refresh ekle**

`_openQuiz` metodunda `_refreshCoins();` satırının hemen altına ekle:

```dart
    _loadMissions();
```

`_openDailyQuiz` metodunda `_refreshCoins();` satırının hemen altına ekle:

```dart
      _loadMissions();
```

- [ ] **Step 6: SliverList index 4'ü güncelle**

Mevcut:
```dart
                if (index == 4) {
                  return const SizedBox.shrink();
                }
```

Yenisi:
```dart
                if (index == 4) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(4),
                      DailyMissionsCard(
                        isKu: ku,
                        missions: _missions,
                        loading: _missionsLoading,
                      ),
                    ),
                  );
                }
```

- [ ] **Step 7: Analyzer ile doğrula**

```powershell
cd zankurd_mobile
dart analyze lib/src/screens/home_screen.dart
```

Beklenen: `No issues found!`

- [ ] **Step 8: Tüm testleri çalıştır**

```powershell
flutter test --reporter=compact
```

Beklenen: Tüm testler yeşil.

- [ ] **Step 9: Commit**

```powershell
git add zankurd_mobile/lib/src/screens/home_screen.dart
git commit -m "feat(missions): integrate DailyMissionsCard into HomeScreen"
```

---

## Task 6: QuizResultScreen Mission Progress + Coin Ödülü

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz_result_screen.dart`

`_QuizResultScreenState`'e şu değişiklikler gerekiyor:
1. Import'lar ekle (`DailyMissionStore`, `MissionToast`)
2. `_recordProgress()` metoduna mission tracking kodu ekle
3. Tamamlanan görevler için `repository.addCoins()` çağır
4. `addPostFrameCallback` ile toast göster

- [ ] **Step 1: Import'ları ekle**

`quiz_result_screen.dart`'taki mevcut import'ların altına ekle:

```dart
import '../data/daily_mission_store.dart';
import '../widgets/mission_toast.dart';
```

- [ ] **Step 2: `_recordProgress` metoduna mission tracking ekle**

Mevcut `_recordProgress` metodunun sonundaki `if (mounted) { setState(...) }` bloğunu bul. Bu bloğun hemen öncesine (masteryStore işlemleri bittikten sonra) şunu ekle:

```dart
    final missionStore = await DailyMissionStore.load();
    final completedMissions = await missionStore.reportQuizCompleted(
      correctAnswers: correctCount,
      category: room.category,
      streakAlive: streak > 0,
    );
    for (final mission in completedMissions) {
      await repository.addCoins(mission.coinReward, 'daily_mission_reward');
    }
```

Ardından `if (mounted) { setState(...) }` bloğu içindeki `setState` çağrısından sonra (setState kapandıktan sonra, if bloğu içinde) şunu ekle:

```dart
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final mission in completedMissions) {
          MissionToast.show(context, mission);
        }
      });
```

Sonuç olarak `_recordProgress` sonu şöyle görünmeli:

```dart
    final missionStore = await DailyMissionStore.load();
    final completedMissions = await missionStore.reportQuizCompleted(
      correctAnswers: correctCount,
      category: room.category,
      streakAlive: streak > 0,
    );
    for (final mission in completedMissions) {
      await repository.addCoins(mission.coinReward, 'daily_mission_reward');
    }

    if (mounted) {
      setState(() {
        _dailyStreak = streak;
        _newAchievements = newAchievements;
        _promotions = promotions;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final mission in completedMissions) {
          MissionToast.show(context, mission);
        }
      });
    }
```

- [ ] **Step 3: Analyzer ile doğrula**

```powershell
cd zankurd_mobile
dart analyze lib/src/screens/quiz_result_screen.dart
```

Beklenen: `No issues found!`

- [ ] **Step 4: Tüm testleri çalıştır**

```powershell
flutter test --reporter=compact
```

Beklenen: Tüm testler yeşil.

- [ ] **Step 5: Commit**

```powershell
git add zankurd_mobile/lib/src/screens/quiz_result_screen.dart
git commit -m "feat(missions): track quiz progress and award coins in result screen"
```

---

## Task 7: QuizScreen Wildcard Mission Hook + Final Doğrulama

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

4 wildcard metoduna (`_useFiftyFifty`, `_useAudience`, ve geriye kalan 2 metod) `_trackWildcardMission()` çağrısı ekle.

- [ ] **Step 1: Import'ları ekle**

`quiz_screen.dart`'taki mevcut import'ların altına ekle:

```dart
import '../data/daily_mission_store.dart';
import '../widgets/mission_toast.dart';
```

- [ ] **Step 2: `_trackWildcardMission` yardımcı metodunu ekle**

`quiz_screen.dart`'ta `_useFiftyFifty` metodunun hemen üstüne ekle:

```dart
  void _trackWildcardMission() {
    DailyMissionStore.load().then((store) {
      store.reportWildcardUsed().then((completed) {
        if (completed != null && mounted) {
          MissionToast.show(context, completed);
        }
      });
    });
  }
```

- [ ] **Step 3: Wildcard metodlarına çağrı ekle**

**`_useFiftyFifty` (satır ~392 civarı)** — `setState` bloğu kapandıktan sonra, `widget.repository.spendCoins(...)` çağrısından önce:

```dart
    _trackWildcardMission();
    widget.repository
        .spendCoins(cost, 'wildcard_fifty_fifty')
        .catchError((_) => false);
```

**`_useAudience` (satır ~408 civarı)** — aynı pattern:

```dart
    _trackWildcardMission();
    widget.repository
        .spendCoins(cost, 'wildcard_audience')
```

**`_useDoubleAnswer` veya `_useChangeQuestion`** (satır ~446 ve ~489 civarı, `playWildcard` çağrısından sonra) — her iki metoda da aynı şekilde `_trackWildcardMission();` ekle. Tam konumlar için `playWildcard` çağrısından sonra eklemek doğru yerdir.

Genel pattern her metod için:
```dart
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();  // <-- bu satırı ekle
    setState(() { ... });
    widget.repository.spendCoins(...).catchError((_) => false);
```

- [ ] **Step 4: Analyzer ile doğrula**

```powershell
cd zankurd_mobile
dart analyze lib/src/screens/quiz_screen.dart
```

Beklenen: `No issues found!`

- [ ] **Step 5: Tüm proje analyzer**

```powershell
cd zankurd_mobile
dart analyze
```

Beklenen: `No issues found!`

- [ ] **Step 6: Tam test suite**

```powershell
flutter test --reporter=compact
```

Beklenen: Önceki (135+) + 8 yeni = **143+ test geçiyor**.

- [ ] **Step 7: Son commit**

```powershell
git add zankurd_mobile/lib/src/screens/quiz_screen.dart
git commit -m "feat(missions): track wildcard use in quiz screen

Sprint 2 complete — günlük görev sistemi aktif.
DailyMissionStore, DailyMissionsCard, MissionToast, addCoins.
8 yeni test, dart analyze temiz."
```

---

## Self-Review

### Spec Coverage

Spec (Eksen 2a) gerekliliklerini karşılıyor mu?

| Gereklilik | Karşılandı mı? |
|---|---|
| `DailyMissionStore` SharedPreferences singleton | Task 2 ✅ |
| `DailyMission` model + `MissionType` enum | Task 1 ✅ |
| 3 görev/gün, gün tohumlu (`DateTime.now().day`) | Task 1 `MissionDefinitions.forDay()` ✅ |
| Progress hook: answerCorrect | Task 6 `reportQuizCompleted` ✅ |
| Progress hook: completeQuiz | Task 6 `reportQuizCompleted` ✅ |
| Progress hook: useWildcard | Task 7 `_trackWildcardMission` ✅ |
| Progress hook: keepStreak | Task 6 `reportQuizCompleted` ✅ |
| Progress hook: playCategory | Task 6 `reportQuizCompleted` ✅ |
| Coin ödülü tamamlanınca | Task 6 `repository.addCoins` ✅ |
| Toast bildirimi (özel, non-default styled) | Task 4 `MissionToast` (gold SnackBar) ✅ |
| HomeScreen'de DailyMissionsCard | Task 5 ✅ |
| İlerleme çubuğu ile görev görünümü | Task 4 `_MissionTile` + `LinearProgressIndicator` ✅ |

### Placeholder Scan

- Tüm kod adımlarında gerçek implementasyon var, "TBD" yok ✅
- Her adımda exact komutlar var ✅
- Test adımlarında expected output var ✅

### Type Consistency

- `DailyMission` Task 1'de tanımlanıyor, Task 2-7'de aynı şekilde kullanılıyor ✅
- `DailyMissionStore.load()` → `DailyMissionStore`, `.missions` → `List<DailyMission>` ✅
- `reportQuizCompleted` signature Task 2 test'leriyle Task 6 çağrısı uyumlu ✅
- `reportWildcardUsed()` → `Future<DailyMission?>` ✅
- `MissionToast.show(context, mission)` Task 4'te tanımlanıyor, Task 6-7'de aynı imzayla çağrılıyor ✅
- `repository.addCoins(int, String)` Task 3'te tanımlanıyor, Task 6'da aynı şekilde çağrılıyor ✅
