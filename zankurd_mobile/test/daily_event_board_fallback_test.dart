// Tur 10 / ekran 021 bekçisi: günlük tur panosu yüklenemiyordu.
// Kusur: istemci yalnız `get_verified_daily_event_board` RPC'sini çağırıyordu;
// bu RPC (2026-11-01_solo_daily_verified.sql) canlıda henüz yokken PostgREST
// "function not found" döner, hata yutulur ve pano "yüklenemedi" gösterirdi.
// Sessizdi: testler RPC'yi hep var sayan sahte istemciyle koşuyordu.
// Şimdi: RPC yoksa eski `get_daily_event_board` okunur (yalnız gösterim),
// yetki/ağ hataları göç eksikliği sayılmaz, hesap değişince eski pano istenmez.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

// PostgREST yanıtın request.method bilgisini de okur.
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
  String? owner = 'synthetic-user';
  @override
  String? get currentUserId => owner;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const board = {
    'participants': 1,
    'top': [
      {'rank': 1, 'name': 'Test', 'correct': 8, 'total': 10, 'seconds': 64},
    ],
  };
  http.Response response(Object? data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  for (final code in ['PGRST202', '42883']) {
    test('yalnız eksik RPC ($code) eski panoya düşer; yazma yapmaz', () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: _Client((r) async {
          calls.add(r.url.pathSegments.last);
          if (calls.last == 'get_verified_daily_event_board') {
            return response({'code': code, 'message': 'Missing RPC'}, 404);
          }
          expect(calls.last, 'get_daily_event_board');
          return response(board);
        }),
      );
      addTearDown(client.dispose);
      final repo = _Repository(client);
      final result = await repo.loadDailyEventBoard();
      expect(result!.top.single.name, 'Test');
      expect(result.participants, 1);
      expect(
        await repo.submitDailyEventResult(correct: 10, total: 10, seconds: 1),
        isFalse,
      );
      expect(calls, [
        'get_verified_daily_event_board',
        'get_daily_event_board',
      ]);
    });
  }

  for (final failure in [
    '42501',
    'XX000',
    'network',
    'timeout',
    'malformed',
    'null',
    'empty',
    'success',
  ]) {
    test('$failure eksik göç değildir; eski pano çağrılmaz', () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: _Client((r) async {
          calls.add(r.url.pathSegments.last);
          return switch (failure) {
            'network' => throw http.ClientException('offline'),
            'timeout' => throw TimeoutException('timed out'),
            'malformed' => response('bad response'),
            'null' => response(null),
            'empty' => response({'participants': 0, 'top': []}),
            'success' => response(board),
            _ => response({'code': failure, 'message': 'Failure'}, 403),
          };
        }),
      );
      addTearDown(client.dispose);
      final result = await _Repository(client).loadDailyEventBoard();
      expect(result != null, failure == 'empty' || failure == 'success');
      expect(calls, ['get_verified_daily_event_board']);
    });
  }

  test('hesap değişince eski pano istenmez; oturumsuz RPC çağrılmaz', () async {
    final pending = Completer<http.Response>();
    final calls = <String>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'test',
      httpClient: _Client((r) {
        calls.add(r.url.pathSegments.last);
        return pending.future;
      }),
    );
    addTearDown(client.dispose);
    final repo = _Repository(client);
    final loading = repo.loadDailyEventBoard();
    await Future<void>.delayed(Duration.zero);
    repo.owner = null;
    pending.complete(
      response({'code': 'PGRST202', 'message': 'Missing RPC'}, 404),
    );
    expect(await loading, isNull);
    expect(await repo.loadDailyEventBoard(), isNull);
    expect(calls, ['get_verified_daily_event_board']);
  });
}
