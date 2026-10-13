import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('üretim bootstrap test AuthProvider kullanmaz', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('AuthProvider.offline()'));
    expect(mainSource, isNot(contains('authProvider = AuthProvider.test();')));
  });

  test(
    'üretim bootstrap test repository yerine offline repository kullanır',
    () {
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(mainSource, contains('OfflineZanKurdRepository()'));
      expect(
        mainSource,
        isNot(contains('repository = MockZanKurdRepository();')),
      );
    },
  );

  test('yerel açılış işleri ilk uzak await öncesinde başlatılır', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final firstRemoteAwait = mainSource.indexOf(
      'final firebaseReady = await initializeFirebaseForBoot(',
    );

    expect(firstRemoteAwait, greaterThan(-1));
    for (final marker in [
      'final languageFuture =',
      'final themeFuture =',
      'final questionBankFuture =',
      'final premiumFuture =',
      'final remoteReadyFuture =',
    ]) {
      final at = mainSource.indexOf(marker);
      expect(at, greaterThan(-1), reason: '$marker bulunamadı');
      expect(
        at,
        lessThan(firstRemoteAwait),
        reason: '$marker uzak servis beklemesinden sonra başlıyor',
      );
    }
  });
}
