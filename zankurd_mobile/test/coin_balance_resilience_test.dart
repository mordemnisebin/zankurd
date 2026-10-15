// Bekçi: jeton bakiyesi ve favori çözümü dayanıklılığı (2026-10-15).
//
// Kusur 1: `loadCoinBalance` bütün `coin_transactions` satırlarını çekip Dart'ta
// topluyordu; PostgREST 1000 satırda kestiği için çok işlemli oyuncunun
// bakiyesi sessizce eksik çıkıyordu. Sınama hesaplarında 1000'den az satır
// olduğundan hiçbir test/elle deneme bunu görmedi. Artık sunucu
// `get_my_coin_balance()` ile toplar; RPC yoksa (PGRST202) satır toplamına düşer.
//
// Kusur 2: favori çözümü `inFilter('id', hepsi)` ile tek GET atıyordu (URL
// sınırı) ve taşıma hatasını yutup boş liste dönüyordu; ağ koptuğunda ekran
// "kaydedilmiş soru yok" diyordu. Artık 50'lik parçalar ve hata → hata durumu.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

class _Repo extends SupabaseZanKurdRepository {
  _Repo(super.client);

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'host-id',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-08-02T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

class _Http extends http.BaseClient {
  _Http(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return handler(request);
  }
}

http.StreamedResponse _json(
  http.BaseRequest request,
  Object? body, {
  int status = 200,
}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    request: request,
    contentLength: bytes.length,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

_Repo _repo(_Http client) => _Repo(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: client,
  ),
);

void main() {
  test('get_my_coin_balance göçü yetkiyi spend_coins gibi sınırlar', () {
    final sql = File(
      'supabase/2026-10-15_jeton_bakiyesi.sql',
    ).readAsStringSync();
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
    expect(sql, contains('auth.uid()'));
    expect(sql, contains('from public, anon'));
    expect(
      sql,
      contains(
        'grant execute on function public.get_my_coin_balance() to authenticated',
      ),
    );
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('2026-10-15_jeton_bakiyesi.sql'),
    );
  });

  group('loadCoinBalance', () {
    test('bakiyeyi sunucu RPC sinden okur, satır çekmez', () async {
      final client = _Http((r) async => _json(r, 4321));
      expect(await _repo(client).loadCoinBalance(), 4321);
      expect(client.requests.map((r) => r.url.path), [
        '/rest/v1/rpc/get_my_coin_balance',
      ]);
    });

    test('RPC henüz yoksa (PGRST202) satır toplamına düşer', () async {
      final client = _Http((r) async {
        if (r.url.path == '/rest/v1/rpc/get_my_coin_balance') {
          return _json(r, {
            'code': 'PGRST202',
            'message': 'Could not find the function',
            'details': null,
            'hint': null,
          }, status: 404);
        }
        return _json(r, [
          {'amount': 100},
          {'amount': -30},
        ]);
      });
      expect(await _repo(client).loadCoinBalance(), 70);
    });

    test('taşıma hatası 0 olmaz, yukarı fırlar', () async {
      final client = _Http((r) async => throw TimeoutException('timeout'));
      await expectLater(
        _repo(client).loadCoinBalance(),
        throwsA(isA<Object>()),
      );
    });
  });

  group('loadFavoriteQuestions', () {
    final ids = [for (var i = 0; i < 120; i++) 'srv-$i'];

    test('çözülmemiş kimlikler 50 li parçalara bölünür', () async {
      final client = _Http((r) async {
        switch (r.url.path) {
          case '/rest/v1/favorite_questions':
            return _json(r, [
              for (final id in ids) {'question_id': id},
            ]);
          default:
            return _json(r, []);
        }
      });
      await _repo(client).loadFavoriteQuestions();
      final chunks = client.requests
          .where((r) => r.url.path == '/rest/v1/quiz_public_questions')
          .map((r) => r.url.queryParameters['id']!.split(',').length)
          .toList();
      expect(chunks, [50, 50, 20]);
    });

    test('taşıma hatası boş durum değil hata olarak çıkar', () async {
      final client = _Http((r) async {
        if (r.url.path == '/rest/v1/favorite_questions') {
          return _json(r, [
            {'question_id': 'srv-1'},
          ]);
        }
        throw TimeoutException('timeout');
      });
      await expectLater(
        _repo(client).loadFavoriteQuestions(),
        throwsA(isA<Object>()),
      );
    });
  });
}
