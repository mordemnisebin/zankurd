// Tur 11 bekçisi: günün turu bitince "Tamamlandı" yazıyor ama "Bugünün
// sıralaması" kimsenin bitirmediğini söylüyordu.
// Kusur: G9 ile istemci sonucu yalnız `submit_verified_daily_event_result`
// ile gönderiyordu; bu RPC (2026-11-01_solo_daily_verified.sql) canlıda
// henüz ⏳ iken PostgREST "function not found" döner, hata yutulur ve bugünün
// sonucu hiç yazılmazdı. Sessizdi: testler doğrulanmış RPC'yi hep var sayardı.
// Şimdi: doğrulanmış RPC yoksa (PGRST202 / 42883) eski canlı
// `submit_daily_event_result` çağrılır; varsa eski yol ASLA çağrılmaz.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.Response> Function(http.Request) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final result = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(result.bodyBytes),
      result.statusCode,
      headers: result.headers,
      request: request,
    );
  }
}

class _Repository extends SupabaseZanKurdRepository {
  _Repository(super.client);
  @override
  String? get currentUserId => 'synthetic-user';
}

http.Response _json(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

const _round = '33333333-3333-4333-8333-333333333333';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['PGRST202', '42883']) {
    test('doğrulanmış RPC yoksa ($code) eski canlı yola düşer', () async {
      final calls = <String>[];
      Map<String, dynamic>? legacyBody;
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: _Client((r) async {
          calls.add(r.url.pathSegments.last);
          if (calls.last == 'submit_verified_daily_event_result') {
            return _json({'code': code, 'message': 'Missing RPC'}, 404);
          }
          legacyBody = jsonDecode(r.body) as Map<String, dynamic>;
          return _json(true);
        }),
      );
      addTearDown(client.dispose);
      final repo = _Repository(client);
      expect(await repo.submitVerifiedDailyResult(_round), isFalse);
      expect(
        await repo.submitDailyEventResult(correct: 8, total: 10, seconds: 64),
        isTrue,
      );
      expect(calls, [
        'submit_verified_daily_event_result',
        'submit_daily_event_result',
      ]);
      expect(legacyBody, {'p_correct': 8, 'p_total': 10, 'p_seconds': 64});
    });
  }

  test('doğrulanmış RPC varsa eski yol hiç çağrılmaz', () async {
    final calls = <String>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'test',
      httpClient: _Client((r) async {
        calls.add(r.url.pathSegments.last);
        return _json(true);
      }),
    );
    addTearDown(client.dispose);
    final repo = _Repository(client);
    expect(await repo.submitVerifiedDailyResult(_round), isTrue);
    expect(
      await repo.submitDailyEventResult(correct: 20, total: 20, seconds: 0),
      isFalse,
    );
    expect(calls, ['submit_verified_daily_event_result']);
  });

  test(
    'yetki hatası (42501) göç eksikliği sayılmaz; eski yol açılmaz',
    () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: _Client((r) async {
          calls.add(r.url.pathSegments.last);
          return _json({'code': '42501', 'message': 'denied'}, 403);
        }),
      );
      addTearDown(client.dispose);
      final repo = _Repository(client);
      expect(await repo.submitVerifiedDailyResult(_round), isFalse);
      expect(
        await repo.submitDailyEventResult(correct: 8, total: 10, seconds: 5),
        isFalse,
      );
      expect(calls, ['submit_verified_daily_event_result']);
    },
  );
}
