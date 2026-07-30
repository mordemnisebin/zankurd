import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';

import 'support/widget_test_helpers.dart';

class _ThrowingConnectivityMonitor implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    throw StateError('connectivity listener unavailable');
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    throw StateError('connectivity check unavailable');
  }
}

class _FixedConnectivityMonitor implements ConnectivityMonitor {
  const _FixedConnectivityMonitor(this.results);

  final List<ConnectivityResult> results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppShell bağlantı eklentisi yoksa da açılır', (tester) async {
    final repository = freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: _ThrowingConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Öğren'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell çevrimdışı iken banner ve tekrar dene gösterir', (
    tester,
  ) async {
    final repository = freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const _FixedConnectivityMonitor([
            ConnectivityResult.none,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('İnternet bağlantısı yok — Kontrol ediliyor…'),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
