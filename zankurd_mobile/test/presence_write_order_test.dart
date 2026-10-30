import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/presence_controller.dart';

class _DelayedGateway implements PresenceGateway {
  bool visible = false;
  int writes = 0;
  Completer<void>? pending;

  @override
  Future<bool> loadVisibility() async => visible;

  @override
  Future<void> setVisibility(bool value) async {
    writes++;
    await pending?.future;
    visible = value;
  }

  @override
  Future<void> touch() async {}
}

void main() {
  for (final switchAccount in [false, true]) {
    testWidgets('Zaman aşımı eski yazmayı iptal etmez; yeni karar '
        'bekleyen yazmayla yarışmaz (hesap değişimi: $switchAccount)', (
      tester,
    ) async {
      final gateway = _DelayedGateway();
      final controller = PresenceController();
      controller.bind(gateway, userId: 'a');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      gateway.pending = Completer<void>();
      final oldWrite = controller.setEnabled(true);
      await tester.pump(const Duration(seconds: 11));
      expect(await oldWrite, isFalse);
      if (switchAccount) {
        controller.updateSession('b');
        await tester.pump();
        controller.updateSession('a');
        await tester.pump();
      }
      expect(controller.canChange, isFalse);
      expect(await controller.setEnabled(true), isFalse);
      expect(await controller.setEnabled(false), isFalse);
      expect(gateway.writes, 1);
      gateway.pending!.complete();
      await tester.pump();
      expect(controller.canChange, isTrue);
      expect(controller.enabled, isTrue);
      gateway.pending = null;
      expect(await controller.setEnabled(false), isTrue);
      await tester.pump(const Duration(minutes: 4));
      expect(gateway.visible, isFalse);
      expect(controller.enabled, isFalse);
      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  }

  for (final dispose in [false, true]) {
    testWidgets('Geç yazma hatası sahipsiz hata üretmez '
        '(dispose: $dispose)', (tester) async {
      final gateway = _DelayedGateway();
      final controller = PresenceController();
      controller.bind(gateway, userId: 'a');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      gateway.pending = Completer<void>();
      final write = controller.setEnabled(true);
      await tester.pump(const Duration(seconds: 11));
      expect(await write, isFalse);
      expect(controller.canChange, isFalse);
      if (dispose) controller.dispose();
      gateway.pending!.completeError(StateError('offline'));
      await tester.pump();
      if (!dispose) {
        expect(controller.canChange, isTrue);
        expect(controller.enabled, isFalse);
      }
      expect(tester.takeException(), isNull);
      if (!dispose) controller.dispose();
    });
  }
}
