import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/repository_holder.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';

import 'support/widget_test_helpers.dart';

class _TokenSource implements PushTokenSource, PushTokenRefreshSource {
  final changes = StreamController<String>.broadcast();
  @override
  Future<String?> currentToken() async => 'device-token';
  @override
  Stream<String> get onTokenRefresh => changes.stream;
}

class _SessionRepository extends MockZanKurdRepository {
  String? user;
  int tokenWrites = 0;
  @override
  String? get currentUserId => user;
  @override
  Future<void> setFcmToken(String token) async {
    tokenWrites++;
    await super.setFcmToken(token);
  }
}

class _Auth extends FakeAuthProvider {
  bool authenticated = false;
  @override
  bool get isAuthenticated => authenticated;
  void signIn() {
    authenticated = true;
    notifyListeners();
  }
}

class _Network implements ConnectivityMonitor {
  final events = StreamController<List<ConnectivityResult>>.broadcast();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events.stream;
}

void main() {
  testWidgets('same shell registers token after sign-in', (tester) async {
    freshMockRepository();
    final repo = _SessionRepository();
    final auth = _Auth();
    final source = _TokenSource();
    await tester.pumpWidget(
      testShell(
        authProvider: auth,
        child: AppShell(
          repository: repo,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          pushTokenSync: PushTokenSync(source: source, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.tokenWrites, 0);
    repo.user = 'signed-in';
    auth.signIn();
    await tester.pumpAndSettle();
    expect(repo.lastFcmToken, 'device-token');
    await tester.pumpWidget(const SizedBox.shrink());
    await source.changes.close();
  });

  testWidgets('recovered repository receives token without app restart', (
    tester,
  ) async {
    final first = freshMockRepository();
    final recovered = MockZanKurdRepository();
    final holder = RepositoryHolder(first);
    final source = _TokenSource();
    await tester.pumpWidget(
      testShell(
        repositoryHolder: holder,
        child: AppShell(
          repository: first,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          pushTokenSync: PushTokenSync(
            source: source,
            repository: first,
            repositoryHolder: holder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    holder.switchTo(recovered);
    await tester.pumpAndSettle();
    expect(recovered.lastFcmToken, 'device-token');
    expect(source.changes.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(source.changes.hasListener, isFalse);
    await source.changes.close();
    holder.dispose();
  });

  testWidgets('connectivity recovery retries token registration', (
    tester,
  ) async {
    freshMockRepository();
    final repo = _SessionRepository()..user = 'signed-in';
    final source = _TokenSource();
    final network = _Network();
    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repo,
          connectivityMonitor: network,
          pushTokenSync: PushTokenSync(source: source, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialWrites = repo.tokenWrites;
    network.events.add([ConnectivityResult.none]);
    await tester.pumpAndSettle();
    network.events.add([ConnectivityResult.wifi]);
    await tester.pumpAndSettle();
    expect(repo.tokenWrites, greaterThan(initialWrites));
    await tester.pumpWidget(const SizedBox.shrink());
    await source.changes.close();
    await network.events.close();
  });
}
