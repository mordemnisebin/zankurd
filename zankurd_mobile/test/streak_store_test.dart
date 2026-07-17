import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakStore.resetInstance();
  });

  test('first play starts the streak at 1', () async {
    final store = await StreakStore.load();
    final streak = await store.recordPlay(now: DateTime(2026, 6, 12, 10));
    expect(streak, 1);
    expect(store.effectiveStreak(now: DateTime(2026, 6, 12, 12)), 1);
  });

  test('second play on the same day does not increase the streak', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12, 10));
    final streak = await store.recordPlay(now: DateTime(2026, 6, 12, 20));
    expect(streak, 1);
  });

  test('consecutive days increase the streak', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));
    final streak = await store.recordPlay(now: DateTime(2026, 6, 14));
    expect(streak, 3);
    expect(store.best, 3);
  });

  test('a skipped day resets the streak to 1', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));
    final streak = await store.recordPlay(now: DateTime(2026, 6, 16));
    expect(streak, 1);
    expect(store.best, 2);
  });

  test('effectiveStreak shows 0 when the chain is broken', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    expect(store.effectiveStreak(now: DateTime(2026, 6, 13)), 1);
    expect(store.effectiveStreak(now: DateTime(2026, 6, 15)), 0);
  });

  test('streak persists across instances', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));

    StreakStore.resetInstance();
    final restored = await StreakStore.load();
    expect(restored.effectiveStreak(now: DateTime(2026, 6, 13)), 2);
    expect(restored.best, 2);
  });

  test('clear resets streak values in memory and preferences', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    expect(store.effectiveStreak(now: DateTime(2026, 6, 12)), 1);

    await store.clear();
    expect(store.effectiveStreak(now: DateTime(2026, 6, 12)), 0);
    expect(store.best, 0);

    StreakStore.resetInstance();
    final reloaded = await StreakStore.load();
    expect(reloaded.effectiveStreak(now: DateTime(2026, 6, 12)), 0);
    expect(reloaded.best, 0);
  });
}

