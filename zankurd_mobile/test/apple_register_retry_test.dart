/// Apple authorization-code kaydı — sınırlı yeniden deneme bekçisi.
///
/// ## Kusur (GPT-6 Pro ALAN 4)
///
/// İlk Apple girişinden sonraki `register` çağrısı geçici bir hatayla (ağ
/// kesintisi, 5xx) düşerse yalnız loglanıyordu; sunucuda iptal jetonu hiç
/// oluşmuyor, hesap silme sırasında Apple bağlantısı iptal edilemiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Giriş başarılı görünür, kayıt hatası kullanıcıya hiç yansımaz; sonuç aylar
/// sonra hesap silinirken "no_token" ile ortaya çıkar. Authorization code ~5
/// dakika geçerli olduğundan kısa ve sınırlı yeniden deneme güvenlidir.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/services/apple_revocation.dart';

class _SequenceClient extends http.BaseClient {
  _SequenceClient(this.statuses);
  final List<int> statuses;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final status =
        statuses[calls < statuses.length ? calls : statuses.length - 1];
    calls++;
    final bytes = utf8.encode(jsonEncode({'registered': status == 200}));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json'},
    );
  }
}

SupabaseClient _client(_SequenceClient c) => SupabaseClient(
  'https://example.supabase.co',
  'sb_publishable_test_key',
  httpClient: c,
);

void main() {
  const fast = [Duration(milliseconds: 1), Duration(milliseconds: 1)];

  test('geçici 5xx sonrası kayıt yeniden denenir ve başarır', () async {
    final c = _SequenceClient([503, 500, 200]);
    final ok = await registerAppleAuthorization(
      _client(c),
      'kod',
      retryDelays: fast,
    );
    expect(ok, isTrue);
    expect(c.calls, 3);
  });

  test('deneme sınırı aşılınca vazgeçer, giriş etkilenmez (false)', () async {
    final c = _SequenceClient([500]);
    final ok = await registerAppleAuthorization(
      _client(c),
      'kod',
      retryDelays: fast,
    );
    expect(ok, isFalse);
    expect(c.calls, 3, reason: 'ilk deneme + iki yeniden deneme');
  });

  test('kalıcı 4xx (Apple kimliği yok) yeniden denenmez', () async {
    final c = _SequenceClient([403]);
    final ok = await registerAppleAuthorization(
      _client(c),
      'kod',
      retryDelays: fast,
    );
    expect(ok, isFalse);
    expect(c.calls, 1);
  });

  test('boş kod hiç çağrı yapmaz', () async {
    final c = _SequenceClient([200]);
    expect(await registerAppleAuthorization(_client(c), '  '), isFalse);
    expect(c.calls, 0);
  });
}
