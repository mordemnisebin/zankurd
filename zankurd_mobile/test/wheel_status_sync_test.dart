import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/wheel_status_provider.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';

import 'support/widget_test_helpers.dart';

class _WheelRepository extends MockZanKurdRepository {
  bool ready = true;
  bool fail = false;
  Completer<int>? award;
  Completer<bool>? nextStatus;

  @override
  Future<bool> canSpinToday() async {
    final pending = nextStatus;
    if (pending != null) {
      nextStatus = null;
      return pending.future;
    }
    if (fail) throw StateError('status unavailable');
    return ready;
  }

  @override
  Future<int> awardSpinCoins() async {
    final amount = award == null ? 50 : await award!.future;
    ready = false;
    return amount;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Ö3: ödülden önceki geç true cevabı tüketilen hakkı geri açmaz',
    () async {
      final repository = _WheelRepository();
      final status = WheelStatusProvider(repository);
      addTearDown(status.dispose);
      await status.refresh();
      expect(status.ready, isTrue);

      final oldResponse = Completer<bool>();
      repository.nextStatus = oldResponse;
      final previousRefresh = status.refresh();
      repository.fail = true;
      await status.spin();
      await status.refresh();
      expect(status.ready, isFalse);

      oldResponse.complete(true);
      await previousRefresh;
      expect(status.ready, isFalse);
      expect(status.error, isNotNull);
    },
  );

  testWidgets('Ö3: çark kapandıktan sonra gelen ödül hub rozetini günceller', (
    tester,
  ) async {
    final repository = _WheelRepository()..award = Completer<int>();
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('play-hub-spin-wheel'));
    await tester.scrollUntilVisible(row, 250);
    expect(find.text('Hazır!'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çevir'));
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SpinWheelScreen), findsNothing);
    expect(find.text('Hazır!'), findsOneWidget);

    repository.award!.complete(50);
    await tester.pumpAndSettle();
    expect(find.text('Hazır!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ö3: uygulamaya dönünce tüketilen çarkın Hazır rozeti kalkar', (
    tester,
  ) async {
    final repository = _WheelRepository();
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-spin-wheel')),
      250,
    );
    expect(find.text('Hazır!'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repository.ready = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Hazır!'), findsNothing);
  });

  testWidgets('Ö3: durum yenilemesi hata verince bayat Hazır rozeti kalmaz', (
    tester,
  ) async {
    final repository = _WheelRepository();
    final refresh = ChangeNotifier();
    addTearDown(refresh.dispose);
    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(repository: repository, refreshSignal: refresh),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-spin-wheel')),
      250,
    );
    expect(find.text('Hazır!'), findsOneWidget);

    repository.fail = true;
    refresh.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('Hazır!'), findsNothing);
  });
}
