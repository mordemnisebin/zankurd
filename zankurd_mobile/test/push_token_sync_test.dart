import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';

class _FixedTokenSource implements PushTokenSource {
  const _FixedTokenSource(this.token);
  final String? token;
  @override
  Future<String?> currentToken() async => token;
}

class _NoSessionRepository extends MockZanKurdRepository {
  @override
  String? get currentUserId => null;
}

void main() {
  test('boş token RPC çağırmaz', () async {
    final repo = MockZanKurdRepository();
    await PushTokenSync(
      source: const _FixedTokenSource(null),
      repository: repo,
    ).sync();
    expect(repo.lastFcmToken, isNull);
  });

  test('dolu token depoya yazılır', () async {
    final repo = MockZanKurdRepository();
    await PushTokenSync(
      source: const _FixedTokenSource('  device-token  '),
      repository: repo,
    ).sync();
    expect(repo.lastFcmToken, 'device-token');
  });

  test('debug no-token nedenini bildirir', () async {
    final debugLines = <String>[];
    await PushTokenSync(
      source: const _FixedTokenSource(null),
      repository: MockZanKurdRepository(),
      debugLog: debugLines.add,
    ).sync();

    expect(debugLines, contains(contains('no token')));
  });

  test('oturum yoksa token RPC çağırmadan nedeni bildirir', () async {
    final debugLines = <String>[];
    final repo = _NoSessionRepository();
    await PushTokenSync(
      source: const _FixedTokenSource('device-token'),
      repository: repo,
      debugLog: debugLines.add,
    ).sync();

    expect(repo.lastFcmToken, isNull);
    expect(debugLines, contains(contains('no session')));
  });
}
