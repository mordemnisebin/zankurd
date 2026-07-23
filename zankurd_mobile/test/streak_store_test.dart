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

  test('addFreeze increments up to the max cap', () async {
    final store = await StreakStore.load();
    expect(store.freezeCount, 0);
    expect(await store.addFreeze(), 1);
    expect(await store.addFreeze(), 2);
    // Üst sınır maxFreeze; üstüne çıkmaz.
    expect(await store.addFreeze(), StreakStore.maxFreeze);
    expect(store.freezeCount, StreakStore.maxFreeze);
  });

  test('willBreakOnPlay only true when a live streak skipped a day', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));
    // Ertesi gün: kırılmaz.
    expect(store.willBreakOnPlay(now: DateTime(2026, 6, 14)), isFalse);
    // Aynı gün: kırılmaz.
    expect(store.willBreakOnPlay(now: DateTime(2026, 6, 13)), isFalse);
    // Bir gün atlandı: kırılır.
    expect(store.willBreakOnPlay(now: DateTime(2026, 6, 15)), isTrue);
  });

  test('freezeAndRecordPlay preserves the streak and spends a token', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));
    await store.addFreeze();
    expect(store.canFreeze(now: DateTime(2026, 6, 15)), isTrue);

    final streak = await store.freezeAndRecordPlay(now: DateTime(2026, 6, 15));
    // Seri sıfırlanmadı, +1 devam etti (2 -> 3).
    expect(streak, 3);
    expect(store.freezeCount, 0);
    expect(store.best, 3);
  });

  test('freezeAndRecordPlay falls back to recordPlay without a token', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));
    // Jeton yok: normal davranış (seri 1'e düşer).
    final streak = await store.freezeAndRecordPlay(now: DateTime(2026, 6, 15));
    expect(streak, 1);
    expect(store.freezeCount, 0);
  });

  test('freeze count persists across instances', () async {
    final store = await StreakStore.load();
    await store.addFreeze();
    StreakStore.resetInstance();
    final restored = await StreakStore.load();
    expect(restored.freezeCount, 1);
  });
}
