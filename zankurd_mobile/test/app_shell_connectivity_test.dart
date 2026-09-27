import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
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

  testWidgets(
    'çevrimdışı şerit SE landscape girişte misafir eylemini ilk viewportta tutar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(667, 375));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});

      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          authProvider: GateAuthProvider(),
          remoteAvailability: RemoteAvailability(reachable: false),
          child: AppShell(
            repository: repository,
            connectivityMonitor: const _FixedConnectivityMonitor([
              ConnectivityResult.wifi,
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sunucuya ulaşılamadı'), findsOneWidget);
      final guestAction = find.text('Misafir olarak devam et');
      expect(guestAction, findsOneWidget);
      expect(
        tester.getBottomRight(guestAction).dy,
        lessThanOrEqualTo(375),
        reason:
            'çevrimdışı şerit misafir eylemini ilk viewport dışına itmemeli',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bağlantı geçişlerinde sosyal kilit canlı güncellenir', (
    tester,
  ) async {
    // 2026-09: `reachable` boot anlık görüntüsüydü; oturum ortasında
    // bağlantı kopunca sosyal yüzey açık kalıyordu. Boot okuması
    // snapshot'tır (kilidi ezmez), sonraki GEÇİŞLER yayılır: kopuşta
    // kilitlenir, dönüşte (ölü depo değilse) açılır.
    final monitor = _StreamConnectivityMonitor(const [ConnectivityResult.wifi]);
    addTearDown(monitor.dispose);
    final availability = RemoteAvailability(reachable: true);
    final repository = freshMockRepository();

    await tester.pumpWidget(
      testShell(
        remoteAvailability: availability,
        child: AppShell(repository: repository, connectivityMonitor: monitor),
      ),
    );
    await tester.pumpAndSettle();
    expect(availability.socialLocked, isFalse);

    monitor.emit(const [ConnectivityResult.none]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      availability.socialLocked,
      isTrue,
      reason: 'bağlantı kopunca sosyal kilit kapanmalı',
    );

    monitor.emit(const [ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      availability.socialLocked,
      isFalse,
      reason: 'bağlantı dönünce kilit açılmalı (ölü depo değil)',
    );
    expect(tester.takeException(), isNull);
  });
}

class _StreamConnectivityMonitor implements ConnectivityMonitor {
  _StreamConnectivityMonitor(this.current);

  List<ConnectivityResult> current;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  void emit(List<ConnectivityResult> results) {
    current = results;
    _controller.add(results);
  }

  void dispose() => _controller.close();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;
}
