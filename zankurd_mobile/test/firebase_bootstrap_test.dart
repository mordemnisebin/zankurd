import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/firebase_bootstrap.dart';

void main() {
  test(
    'Firebase init asılı kalırsa açılış devam eder ve Crashlytics beklenmez',
    () async {
      var crashlyticsCalled = false;
      final stopwatch = Stopwatch()..start();

      final ready = await initializeFirebaseForBoot(
        initialize: () => Completer<void>().future,
        disableCrashlytics: () async {
          crashlyticsCalled = true;
        },
        timeout: const Duration(milliseconds: 80),
      );

      stopwatch.stop();
      expect(ready, isFalse);
      expect(crashlyticsCalled, isFalse);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    },
  );

  test('Crashlytics kapatma asılı kalırsa açılış yine tamamlanır', () async {
    final stopwatch = Stopwatch()..start();

    final ready = await initializeFirebaseForBoot(
      initialize: () async {},
      disableCrashlytics: () => Completer<void>().future,
      timeout: const Duration(milliseconds: 80),
    );

    stopwatch.stop();
    expect(ready, isTrue);
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });

  // Kusur: 4 sn zaman aşımı "Firebase hiç gelmedi" sayılıyor, bildirim dokunuşu
  // ve ön plan push abonelikleri o süreçte kalıcı olarak kurulmuyordu.
  // Niçin sessiz: hata yok, yalnız yavaş cihazda bildirim akışı ölü kalırdı.
  test('yavaş başlatma sonradan bitince geç hazır kancası çalışır', () async {
    final slow = Completer<void>();
    final events = <String>[];
    final ready = await initializeFirebaseForBoot(
      initialize: () => slow.future,
      disableCrashlytics: () async => events.add('crashlytics'),
      onLateReady: () async => events.add('late'),
      timeout: const Duration(milliseconds: 40),
    );
    expect(ready, isFalse);
    expect(events, isEmpty);
    slow.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, ['crashlytics', 'late']);
  });

  test('zamanında hazır olunca geç kanca çağrılmaz', () async {
    var late = 0;
    final ready = await initializeFirebaseForBoot(
      initialize: () async {},
      disableCrashlytics: () async {},
      onLateReady: () async => late++,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ready, isTrue);
    expect(late, 0);
  });

  test('başlatma gerçekten hata verirse geç kanca çağrılmaz', () async {
    var late = 0;
    final ready = await initializeFirebaseForBoot(
      initialize: () async => throw StateError('yapılandırma yok'),
      disableCrashlytics: () async {},
      onLateReady: () async => late++,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ready, isFalse);
    expect(late, 0);
  });
}
