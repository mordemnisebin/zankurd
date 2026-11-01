import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/paid_freeze_intent.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';

const _paidIntent = PaidFreezeIntent(
  ownerId: 'test-owner',
  roundId: 'solo:store-test',
  idempotencyKey:
      'zankurd.quiz_result_progress_receipt.test-owner:solo:store-test',
  playedDay: '2026-06-15',
  previousLastDay: '2026-06-12',
  targetCurrent: 8,
  targetBest: 8,
  playedDays: ['2026-06-12', '2026-06-15'],
  frozenDays: ['2026-06-13', '2026-06-14'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');

  setUp(() {
    SharedPreferences.resetStatic();
    StreakStore.resetInstance();
    LocalProgressScope.debugReset();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
    StreakStore.resetInstance();
  });

  test(
    'snapshot await sırasında hesap değişse placement yeni hesaba yazılmaz',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final storage = <String, Object>{
        'flutter.zankurd.scope.owner-b.zankurd.placement.v1.level': 'destpek',
      };
      LocalProgressScope.bind('owner-a');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getAll') {
              return Map<String, Object>.of(storage);
            }
            final args = Map<String, Object?>.from(call.arguments as Map);
            final key = args['key'] as String;
            if (call.method == 'setInt' && key.endsWith('zankurd.xp.total')) {
              entered.complete();
              await release.future;
            }
            if (call.method == 'remove') {
              storage.remove(key);
            } else {
              storage[key] = args['value']!;
            }
            return true;
          });
      final prefs = await SharedPreferences.getInstance();
      final pending = LocalProgressSnapshot.write(
        prefs,
        const ProgressSnapshot(
          xp: 100,
          placementLevel: 'navin',
          placementUpdatedAt: 100,
        ),
      );
      await entered.future;
      LocalProgressScope.bind('owner-b');
      release.complete();
      expect(await pending, isTrue);
      expect(
        storage['flutter.zankurd.scope.owner-b.zankurd.placement.v1.level'],
        'destpek',
      );
      expect(
        storage['flutter.zankurd.scope.owner-a.zankurd.placement.v1.level'],
        'navin',
      );
    },
  );

  for (final failAt in ['pending', 'lastDay', 'remove']) {
    for (final throwError in [false, true]) {
      test(
        'journal hata sonrası normal oyun geri alınmaz: at=$failAt throw=$throwError',
        () async {
          final storage = <String, Object>{
            'flutter.zankurd.streak.current': 7,
            'flutter.zankurd.streak.best': 7,
            'flutter.zankurd.streak.lastDay': '2026-06-12',
            'flutter.zankurd.streak.freeze': 1,
          };
          var failNext = true;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'getAll') {
                  return Map<String, Object>.of(storage);
                }
                final args = Map<String, Object?>.from(call.arguments as Map);
                final key = args['key'] as String;
                final target = switch (failAt) {
                  'pending' =>
                    call.method == 'setString' &&
                        key.endsWith('.paidFreezePending'),
                  'remove' =>
                    call.method == 'remove' &&
                        key.endsWith('.paidFreezePending'),
                  _ => call.method == 'setString' && key.endsWith('.lastDay'),
                };
                if (target && failNext) {
                  failNext = false;
                  if (throwError) throw PlatformException(code: 'injected');
                  return false;
                }
                if (call.method == 'remove') {
                  storage.remove(key);
                } else {
                  storage[key] = args['value']!;
                }
                return true;
              });
          final store = await StreakStore.load();
          await expectLater(
            store.applyPaidFreezeIntent(_paidIntent),
            throwsA(anything),
          );
          expect(
            storage.containsKey('flutter.zankurd.streak.paidFreezePending'),
            failAt != 'pending',
          );
          if (failAt == 'pending') {
            // Diskte olmayan iyimser cache kaydı kurtarma gibi uygulanamaz.
            expect(await StreakStore.load(), same(store));
            expect(storage['flutter.zankurd.streak.current'], 7);
            await store.applyPaidFreezeIntent(_paidIntent);
            expect(store.effectiveStreak(now: DateTime(2026, 6, 15)), 8);
          }

          // Aynı önbellekli örnekle başka bir oyun: eski journal önce çözülmeli.
          expect(await store.recordPlay(now: DateTime(2026, 6, 16)), 9);
          expect(await StreakStore.load(), same(store));
          expect(store.freezeCount, 1);
          StreakStore.resetInstance();
          final restored = await StreakStore.load();
          expect(restored.effectiveStreak(now: DateTime(2026, 6, 16)), 9);
          expect(
            storage.containsKey('flutter.zankurd.streak.paidFreezePending'),
            isFalse,
          );
        },
      );
    }
  }
}
