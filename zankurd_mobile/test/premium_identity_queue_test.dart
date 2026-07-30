import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

void main() {
  test('premium identity operations run in requested order', () async {
    final queue = PremiumIdentityQueue();
    final firstGate = Completer<void>();
    final events = <String>[];

    final first = queue.schedule(() async {
      events.add('login-start');
      await firstGate.future;
      events.add('login-end');
    });
    final second = queue.schedule(() async {
      events.add('logout');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['login-start']);
    firstGate.complete();
    await Future.wait([first, second]);
    expect(events, ['login-start', 'login-end', 'logout']);
  });

  test('one failed identity operation does not block the next one', () async {
    final queue = PremiumIdentityQueue();
    var secondRan = false;

    final first = queue.schedule(() async => throw StateError('failed'));
    final second = queue.schedule(() async => secondRan = true);

    await expectLater(first, throwsStateError);
    await second;
    expect(secondRan, isTrue);
  });
}
