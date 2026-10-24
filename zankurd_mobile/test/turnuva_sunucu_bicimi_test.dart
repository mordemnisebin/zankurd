// Bekçi: gerçek turnuva şeması çözümü (2026-10-17, özellik bayrağı kapalı).
//
// Kusur 1: `get_tournament_bracket` tur numarasını 'round' adıyla gönderir,
// `TournamentRound.fromJson` 'roundNumber' okuyordu; her tur 0 olarak çözülüp
// "son tur" ve sıralama türetimi yanlışlıyordu.
// Kusur 2: tur adları 16 oyuncu varsayımıyla ("Son 16" ile başlar) sabitti;
// canlı turnuvalar 4 kişilik (2 tur) ve ilk tur "Son 16" yazıyordu.
// Kusur 3: ağ hatası null dönüp çevrimdışı bot şemasına düşüyordu; kullanıcı
// "gerçek insanlar" yerine sahte rakiplerle oynuyordu.
// Hepsi bayrak kapalıyken sessizdi: ekran hiç açılmıyor, sınama sunucusunda 16
// kişilik turnuva kurulmamıştı.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

class _Repo extends SupabaseZanKurdRepository {
  _Repo(super.client);

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-08-02T00:00:00.000Z',
  );

  @override
  Future<void> ensureProfile() async {}
}

class _Http extends http.BaseClient {
  _Http(this.status, this.body);
  final int status;
  final Object? body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

_Repo _repo(int status, Object? body) => _Repo(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: _Http(status, body),
  ),
);

void main() {
  test('sunucunun "round" alanı tur numarası olarak okunur', () {
    final bracket = TournamentBracket.fromJson(const {
      'tournamentId': 't',
      'userId': 'u',
      'currentRound': 0,
      'status': 'active',
      'createdAt': '2026-10-17T00:00:00Z',
      'rounds': [
        {
          'round': 1,
          'matches': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        },
        {
          'round': 2,
          'matches': [
            {'id': 'c'},
          ],
        },
      ],
    });
    expect(bracket.rounds.map((r) => r.roundNumber), [1, 2]);
    // Eski/yerel biçim de çalışmaya devam eder.
    expect(
      TournamentRound.fromJson(const {
        'roundNumber': 3,
        'matches': [],
      }).roundNumber,
      3,
    );
  });

  test(
    'tur adları tur sayısından türetilir (4 kişilik: Yarı Final, Final)',
    () {
      expect(tournamentRoundNames(false, 2), ['Yarı Final', 'Final']);
      expect(tournamentRoundNames(true, 2), ['Nîv-Fînal', 'Fînal']);
      expect(tournamentRoundNames(false, 4), [
        'Son 16',
        'Çeyrek Final',
        'Yarı Final',
        'Final',
      ]);
      expect(tournamentRoundNames(false, 1), ['Final']);
      expect(tournamentRoundNames(false, 5), hasLength(5));
    },
  );

  test('ağ/sunucu hatası çevrimdışı bot şemasına düşmez, fırlar', () async {
    final repo = _repo(500, {
      'code': 'XX000',
      'message': 'boom',
      'details': null,
      'hint': null,
    });
    await expectLater(
      repo.loadTournamentBracket(),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repo.loadRealTournamentBracket(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('RPC henüz yoksa (PGRST202) null döner', () async {
    final repo = _repo(404, {
      'code': 'PGRST202',
      'message': 'Could not find the function',
      'details': null,
      'hint': null,
    });
    expect(await repo.loadRealTournamentBracket(), isNull);
    expect(await repo.joinRealTournament(), isNull);
  });
}
