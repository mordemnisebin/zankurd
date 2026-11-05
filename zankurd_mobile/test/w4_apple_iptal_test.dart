/// W4 (GPT-6 Pro ALAN 4 #1 #10 #20) Apple iptali istemci bekçisi.
///
/// ## Kusurlar
///
/// * #1: Sunucu saklı jeton yokken HTTP 200 `{revoked:false, reason:'no_token'}`
///   döner; istemci "çağrı hatasız bitti"yi başarı sayıyordu. Yalnız
///   `revoked == true` başarıdır.
/// * #10: Girişten sonraki kayıt `unawaited` idi; hızlı hesap silmede iptal,
///   henüz yazılmamış jetonu görmeden `no_token` dönüyordu. İptal artık süren
///   kaydı bekler; kayıt hâlâ bitmediyse tek kullanımlık kodu iptal çağrısına
///   ekler.
/// * #20: İstemci yalnız `identities`e, Edge `app_metadata`ya da bakıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: iptal "başarılı" görünür, Apple'daki bağlantı açık kalır.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/apple_revocation.dart';

class _Http extends http.BaseClient {
  _Http(this.respond);

  final Future<(int, Map<String, dynamic>)> Function(
    Map<String, dynamic> body,
    int index,
  )
  respond;
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request && request.body.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(request.body) as Map)
        : <String, dynamic>{};
    bodies.add(body);
    final (status, payload) = await respond(body, bodies.length - 1);
    final bytes = utf8.encode(jsonEncode(payload));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json'},
    );
  }
}

SupabaseClient _client(http.Client c) => SupabaseClient(
  'https://example.supabase.co',
  'sb_publishable_test_key',
  httpClient: c,
);

User _user({
  Map<String, dynamic> meta = const {},
  List<String> ids = const [],
}) => User(
  id: 'u1',
  appMetadata: meta,
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-05T00:00:00Z',
  identities: [
    for (final p in ids)
      UserIdentity(
        id: 'i-$p',
        userId: 'u1',
        identityData: const {},
        identityId: 'i-$p',
        provider: p,
        createdAt: '2026-11-05T00:00:00Z',
        lastSignInAt: '2026-11-05T00:00:00Z',
      ),
  ],
);

class _AppleRepo extends SupabaseZanKurdRepository {
  _AppleRepo(super.client);

  @override
  bool get hasAppleIdentity => true;

  @override
  Future<bool> removeAllOwnAvatarObjects() async => true;
}

void main() {
  setUp(resetAppleRegistrationStateForTest);

  test('#1: no_token (HTTP 200, revoked:false) BAŞARI sayılmaz', () async {
    final h = _Http(
      (_, _) async => (200, {'revoked': false, 'reason': 'no_token'}),
    );
    expect(await revokeAppleAuthorization(_client(h)), isFalse);
  });

  test('#1: yalnız revoked == true başarıdır', () async {
    final h = _Http((_, _) async => (200, {'revoked': true}));
    expect(await revokeAppleAuthorization(_client(h)), isTrue);
    expect(h.bodies.single, {'action': 'revoke'});
  });

  test(
    '#1: 502 revoke_failed (iptal kuyrukta) başarı değil, fırlatmaz',
    () async {
      final h = _Http(
        (_, _) async =>
            (502, {'revoked': false, 'error': 'revoke_failed', 'queued': true}),
      );
      expect(await revokeAppleAuthorization(_client(h)), isFalse);
    },
  );

  test('#10: iptal süren kaydı BEKLER; kayıt bitince kod eklenmez', () async {
    final gate = Completer<void>();
    final order = <String>[];
    final h = _Http((body, _) async {
      if (body['action'] == 'register') {
        await gate.future;
        order.add('register-done');
        return (200, {'registered': true});
      }
      order.add('revoke');
      return (200, {'revoked': true});
    });
    final client = _client(h);
    final reg = registerAppleAuthorization(client, 'code-1');
    final revoke = revokeAppleAuthorization(client);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(order, isEmpty, reason: 'kayıt bitmeden iptal gönderilmemeli');
    gate.complete();
    expect(await reg, isTrue);
    expect(await revoke, isTrue);
    expect(order, ['register-done', 'revoke']);
    expect(h.bodies.last, {
      'action': 'revoke',
    }, reason: 'kayıt başarılı: kod eklenmez');
  });

  test(
    '#10: kayıt başarısızsa kod iptal çağrısına eklenir (sunucu takas eder)',
    () async {
      final h = _Http((body, _) async {
        if (body['action'] == 'register') {
          return (502, {'error': 'exchange_failed'});
        }
        return (200, {'revoked': true});
      });
      final client = _client(h);
      await registerAppleAuthorization(
        client,
        'code-2',
        retryDelays: const [Duration(milliseconds: 1)],
      );
      expect(await revokeAppleAuthorization(client), isTrue);
      expect(h.bodies.last, {
        'action': 'revoke',
        'authorization_code': 'code-2',
      });
    },
  );

  test('#10: kalıcı ret (403 apple_subject_mismatch) kodu bırakır', () async {
    final h = _Http((body, _) async {
      if (body['action'] == 'register') {
        return (403, {'registered': false, 'error': 'apple_subject_mismatch'});
      }
      return (200, {'revoked': false, 'reason': 'no_token'});
    });
    final client = _client(h);
    expect(await registerAppleAuthorization(client, 'code-3'), isFalse);
    await revokeAppleAuthorization(client);
    expect(h.bodies.last, {'action': 'revoke'});
  });

  test(
    '#20: Apple kimliği ölçütü Edge ile aynı (identities + app_metadata)',
    () {
      expect(userHasAppleIdentity(null), isFalse);
      expect(userHasAppleIdentity(_user(ids: ['google'])), isFalse);
      expect(userHasAppleIdentity(_user(ids: ['google', 'apple'])), isTrue);
      expect(userHasAppleIdentity(_user(meta: {'provider': 'apple'})), isTrue);
      expect(
        userHasAppleIdentity(
          _user(
            meta: {
              'providers': ['email', 'apple'],
            },
          ),
        ),
        isTrue,
      );
      expect(
        userHasAppleIdentity(_user(meta: {'provider': 'anonymous'})),
        isFalse,
      );
    },
  );

  // Copilot RET: jeton saklanamadı + Apple iptali başarısız → yeniden denenecek
  // kayıt yok; hesap silinmemeli.
  test('revoke_failed_unsaved: hesap silme DURUR (RPC çağrılmaz)', () async {
    final paths = <String>[];
    final h = _Http((body, _) async {
      if (body['action'] == 'revoke') {
        return (502, {'revoked': false, 'error': 'revoke_failed_unsaved'});
      }
      return (200, <String, dynamic>{});
    });
    final client = _client(h);
    await expectLater(
      revokeAppleAuthorization(client),
      throwsA(isA<AppleRevokeUnsavedException>()),
    );
    await expectLater(
      _AppleRepo(client).deleteMyAccount(),
      throwsA(isA<AppleRevokeUnsavedException>()),
    );
    expect(
      h.bodies.every((b) => b['action'] == 'revoke'),
      isTrue,
      reason: '$paths',
    );
  });

  test('revoke_failed (jeton kuyrukta) hesap silmeyi engellemez', () async {
    final h = _Http((_, _) async {
      return (
        502,
        {'revoked': false, 'error': 'revoke_failed', 'queued': true},
      );
    });
    expect(await revokeAppleAuthorization(_client(h)), isFalse);
  });
}
