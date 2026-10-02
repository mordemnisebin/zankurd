import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/apple_revocation.dart';
import 'package:zankurd_mobile/src/services/native_auth_service.dart';

/// "Sign in with Apple" iptali: hesap silme sırası ve hata davranışı.
///
/// ## Niçin
///
/// Kılavuz 5.1.1(v): Apple ile girişli hesap silinirken Apple bağlantısı da
/// iptal edilir. Sıra önemlidir — `delete_my_account` kullanıcıyı siler, ondan
/// sonra JWT geçersizdir ve `apple-revoke` çağrılamaz. İkinci ilke: iptal
/// (Edge Function dağıtılmamış, Apple erişilemez…) hiçbir koşulda hesap
/// silmeyi ENGELLEMEZ.
class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient({this.functionStatus = 200});

  final int functionStatus;
  final requests = <({String path, Map<String, dynamic>? body})>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    Map<String, dynamic>? body;
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    }
    requests.add((path: request.url.path, body: body));

    final isFunction = request.url.path.startsWith('/functions/v1/');
    final status = isFunction ? functionStatus : 200;
    final bytes = utf8.encode(
      isFunction
          ? jsonEncode({'revoked': status == 200})
          : jsonEncode({'deleted': true}),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _AppleRepository extends SupabaseZanKurdRepository {
  _AppleRepository(super.client, {required this.apple});

  final bool apple;

  @override
  bool get hasAppleIdentity => apple;
}

SupabaseClient _client(_RecordingHttpClient http) => SupabaseClient(
  'https://example.supabase.co',
  'sb_publishable_test_key',
  httpClient: http,
);

void main() {
  test('Apple hesabında önce apple-revoke, SONRA delete_my_account', () async {
    final http = _RecordingHttpClient();
    final repository = _AppleRepository(_client(http), apple: true);

    await repository.deleteMyAccount();

    expect(http.requests.map((r) => r.path), [
      '/functions/v1/apple-revoke',
      '/rest/v1/rpc/delete_my_account',
    ]);
    expect(http.requests.first.body, {'action': 'revoke'});
  });

  test('apple-revoke başarısız (500) olsa da hesap silme sürer', () async {
    final http = _RecordingHttpClient(functionStatus: 500);
    final repository = _AppleRepository(_client(http), apple: true);

    await repository.deleteMyAccount();

    expect(
      http.requests.map((r) => r.path),
      ['/functions/v1/apple-revoke', '/rest/v1/rpc/delete_my_account'],
      reason: 'İptal hatası kullanıcının silme hakkını engelleyemez.',
    );
  });

  test('Apple kimliği olmayan hesapta fonksiyon hiç çağrılmaz', () async {
    final http = _RecordingHttpClient();
    final repository = _AppleRepository(_client(http), apple: false);

    await repository.deleteMyAccount();

    expect(http.requests.map((r) => r.path), [
      '/rest/v1/rpc/delete_my_account',
    ]);
  });

  test('registerAppleAuthorization kodu register eylemiyle gönderir', () async {
    final http = _RecordingHttpClient();

    await registerAppleAuthorization(_client(http), ' code-123 ');

    expect(http.requests.single.path, '/functions/v1/apple-revoke');
    expect(http.requests.single.body, {
      'action': 'register',
      'authorization_code': 'code-123',
    });
  });

  test('boş kod için ağ çağrısı yapılmaz; hata fırlatılmaz', () async {
    final http = _RecordingHttpClient(functionStatus: 500);

    await registerAppleAuthorization(_client(http), '   ');
    expect(http.requests, isEmpty);

    // 500 → yutulur, çağıran akış (giriş) kırılmaz.
    await registerAppleAuthorization(_client(http), 'code');
    expect(http.requests, hasLength(1));
  });

  test('NativeAuthCredential.apple yetkilendirme kodunu taşır', () {
    const credential = NativeAuthCredential.apple(
      idToken: 'id',
      rawNonce: 'nonce',
      authorizationCode: 'auth-code',
    );
    expect(credential.authorizationCode, 'auth-code');
    expect(credential.provider, NativeAuthProvider.apple);
    const google = NativeAuthCredential.google(idToken: 'id');
    expect(google.authorizationCode, isNull);
  });

  test('userHasAppleIdentity yalnız apple sağlayıcısını sayar', () {
    expect(userHasAppleIdentity(null), isFalse);
    User userWith(List<String> providers) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-02T00:00:00Z',
      identities: [
        for (final p in providers)
          UserIdentity(
            id: 'i-$p',
            userId: 'u1',
            identityData: const {},
            identityId: 'i-$p',
            provider: p,
            createdAt: '2026-10-02T00:00:00Z',
            lastSignInAt: '2026-10-02T00:00:00Z',
          ),
      ],
    );
    expect(userHasAppleIdentity(userWith(['google'])), isFalse);
    expect(userHasAppleIdentity(userWith(['google', 'apple'])), isTrue);
  });
}
