import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

class _MissingFreezeRpc extends http.BaseClient {
  int calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({'code': 'PGRST202', 'message': 'Function missing'}),
        ),
      ),
      404,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _Repository extends SupabaseZanKurdRepository {
  _Repository(super.client);

  int legacyCharges = 0;
  String ownerId = 'freeze-user';
  Completer<void>? profileGate;

  @override
  String? get currentUserId => ownerId;

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'freeze-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-31T00:00:00Z',
  );

  @override
  Future<void> ensureProfile() async {
    await profileGate?.future;
  }

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    legacyCharges++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profil beklerken hesap değişince tahsilat RPC gönderilmez', () async {
    final transport = _MissingFreezeRpc();
    final repository = _Repository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: transport,
      ),
    );
    repository.profileGate = Completer<void>();
    final pending = repository.spendStreakFreeze(
      idempotencyKey: 'owner-a-round',
      allowLegacyFallback: false,
    );
    await Future<void>.delayed(Duration.zero);
    repository.ownerId = 'owner-b';
    repository.profileGate!.complete();
    expect((await pending).succeeded, isFalse);
    expect(transport.calls, 0);
    expect(repository.legacyCharges, 0);
  });

  test(
    'yeniden denenebilir koruma eksik RPC ile eski tahsilata düşmez',
    () async {
      final transport = _MissingFreezeRpc();
      final repository = _Repository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: transport,
        ),
      );
      final result = await repository.spendStreakFreeze(
        idempotencyKey: 'freeze-round',
        allowLegacyFallback: false,
      );
      expect(result.succeeded, isFalse);
      expect(result.idempotent, isTrue);
      expect(transport.calls, 1);
      expect(repository.legacyCharges, 0);
    },
  );

  test('eski çağıran için fallback tek seferlik olarak korunur', () async {
    final repository = _Repository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _MissingFreezeRpc(),
      ),
    );
    final result = await repository.spendStreakFreeze(
      idempotencyKey: 'legacy-round',
    );
    expect(result.succeeded, isTrue);
    expect(result.idempotent, isFalse);
    expect(repository.legacyCharges, 1);
  });
}
