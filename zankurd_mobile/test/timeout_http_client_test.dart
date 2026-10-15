// Bekçi: Supabase HTTP istekleri süre sınırlı olmalı (2026-10-15).
//
// Kusur: `Supabase.initialize` özel istemci almadan çağrılıyordu; yarı kopuk
// ağda mağaza satın alma, ad kaydı, düello yükleme vb. işletim sisteminin
// soket sınırına dek asılı kalıp düğmeleri sonsuza kilitliyordu. Testler hep
// anında yanıt veren sahte istemciyle çalıştığı için asılma hiç görülmedi.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zankurd_mobile/src/data/timeout_http_client.dart';

class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

void main() {
  test('asılı kalan istek TimeoutException ile biter', () async {
    final client = TimeoutHttpClient(
      _HangingClient(),
      (_) => const Duration(milliseconds: 20),
    );
    await expectLater(
      client.get(Uri.parse('https://example.supabase.co/rest/v1/x')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('yükleme yolları uzun, edge fonksiyonları orta, geri kalan kısa', () {
    Duration of(String path) => TimeoutHttpClient.defaultTimeoutFor(
      Uri.parse('https://example.supabase.co$path'),
    );
    expect(of('/rest/v1/rpc/spend_coins'), const Duration(seconds: 15));
    expect(of('/auth/v1/token'), const Duration(seconds: 15));
    expect(of('/functions/v1/send-push'), const Duration(seconds: 30));
    expect(of('/storage/v1/object/avatars/a.png'), const Duration(seconds: 60));
  });

  test('main.dart Supabase.initialize a süre sınırlı istemci verir', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('httpClient: TimeoutHttpClient()'));
  });
}
