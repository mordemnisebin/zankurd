import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
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

  // 2026-10-26: jeton değişince damga yazılır; eşitleme en yeniyi seçer
  // (SnapshotStreak.merge). Damga yoksa harcanan jeton geri gelebilirdi.
  test('jeton satın alma ve harcama değişiklik zamanını damgalar', () async {
    final store = await StreakStore.load();
    final prefs = await SharedPreferences.getInstance();
    expect(LocalProgressSnapshot.read(prefs).streak.freezeAt, isNull);
    await store.addFreeze();
    final bought = LocalProgressSnapshot.read(prefs).streak.freezeAt;
    expect(bought, isNotNull);

    await store.recordPlay(now: DateTime(2026, 6, 12));
    await store.recordPlay(now: DateTime(2026, 6, 13));
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.freezeAndRecordPlay(now: DateTime(2026, 6, 15));
    final spent = LocalProgressSnapshot.read(prefs).streak;
    expect(spent.freeze, 0);
    expect(spent.freezeAt, greaterThan(bought!));
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

  test(
    'freezeAndRecordPlay falls back to recordPlay without a token',
    () async {
      final store = await StreakStore.load();
      await store.recordPlay(now: DateTime(2026, 6, 12));
      await store.recordPlay(now: DateTime(2026, 6, 13));
      // Jeton yok: normal davranış (seri 1'e düşer).
      final streak = await store.freezeAndRecordPlay(
        now: DateTime(2026, 6, 15),
      );
      expect(streak, 1);
      expect(store.freezeCount, 0);
    },
  );

  test('freeze count persists across instances', () async {
    final store = await StreakStore.load();
    await store.addFreeze();
    StreakStore.resetInstance();
    final restored = await StreakStore.load();
    expect(restored.freezeCount, 1);
  });

  // Kusur: `_isYesterday` dünü `now.subtract(24 saat)` ile buluyordu. Saat
  // ileri alınan gecenin ertesi sabahı (00:xx) 24 saat önce İKİ gün öncesine
  // düşebilir; seri sessizce 1'e dönerdi. Takvim günü aritmetiği (DateTime(y,
  // m, d - 1)) saatten bağımsızdır. Hata yalnız yaz/kış saati geçiş
  // gecelerinde ve yalnız o saat dilimindeki cihazlarda görünür; bu yüzden
  // test makinesinin dilimi ne olursa olsun geçiş günlerini tarar.
  group('gün sınırı takvim aritmetiğidir', () {
    final crossings = <(DateTime, DateTime)>[
      // AB: 29 Mart 2026 ileri, 25 Ekim 2026 geri. ABD: 8 Mart, 1 Kasım.
      (DateTime(2026, 3, 28, 23, 30), DateTime(2026, 3, 29, 0, 30)),
      (DateTime(2026, 3, 29, 23, 30), DateTime(2026, 3, 30, 0, 30)),
      (DateTime(2026, 10, 24, 23, 30), DateTime(2026, 10, 25, 0, 30)),
      (DateTime(2026, 10, 25, 23, 30), DateTime(2026, 10, 26, 0, 30)),
      (DateTime(2026, 3, 7, 23, 30), DateTime(2026, 3, 8, 0, 30)),
      (DateTime(2026, 3, 8, 23, 30), DateTime(2026, 3, 9, 0, 30)),
      (DateTime(2026, 10, 31, 23, 30), DateTime(2026, 11, 1, 0, 30)),
      (DateTime(2026, 11, 1, 23, 30), DateTime(2026, 11, 2, 0, 30)),
      // Ay, yıl ve artık yıl sınırları.
      (DateTime(2026, 2, 28, 23, 59), DateTime(2026, 3, 1, 0, 1)),
      (DateTime(2028, 2, 28, 12), DateTime(2028, 2, 29, 12)),
      (DateTime(2028, 2, 29, 23, 59), DateTime(2028, 3, 1, 0, 1)),
      (DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1, 0, 1)),
    ];
    for (final (first, next) in crossings) {
      test('$first -> $next seriyi sürdürür', () async {
        final store = await StreakStore.load();
        await store.recordPlay(now: first);
        expect(store.willBreakOnPlay(now: next), isFalse);
        expect(store.effectiveStreak(now: next), 1);
        expect(await store.recordPlay(now: next), 2);
      });
    }

    test('iki gün atlayınca (geçiş günü dahil) seri yine kırılır', () async {
      final store = await StreakStore.load();
      await store.recordPlay(now: DateTime(2026, 3, 28, 12));
      expect(store.willBreakOnPlay(now: DateTime(2026, 3, 30, 0, 30)), isTrue);
      expect(await store.recordPlay(now: DateTime(2026, 3, 30, 0, 30)), 1);
    });

    test('24 saatlik çıkarma kaynakta kalmadı', () {
      final source = File('lib/src/data/streak_store.dart').readAsStringSync();
      expect(source, isNot(contains('subtract(const Duration(days: 1))')));
      expect(source, contains('DateTime(now.year, now.month, now.day - 1)'));
    });
  });
}
