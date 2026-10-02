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
}
