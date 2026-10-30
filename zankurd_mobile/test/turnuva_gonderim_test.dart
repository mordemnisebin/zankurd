import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/widget_test_helpers.dart';

const _sent = '2026-10-30T10:00:00.000Z';
TournamentMatch _match({
  bool one = false,
  bool two = false,
  bool expired = false,
}) => TournamentMatch.fromJson({
  'id': 'm',
  'playerOneId': 'me',
  'playerOneName': 'Roj',
  'playerTwoId': 'other',
  'playerTwoName': 'Şîlan',
  'playerOneScore': 0,
  'playerTwoScore': 0,
  'p1_submitted_at': one ? _sent : null,
  'p2_submitted_at': two ? _sent : null,
  'status': expired || (one && two) ? 'completed' : 'active',
  'winnerId': expired || (one && two) ? (one ? 'me' : '') : '',
  'deadline': expired ? '2020-01-01T00:00:00Z' : '2099-01-01T00:00:00Z',
});
TournamentBracket _bracket(TournamentMatch match) => TournamentBracket(
  tournamentId: 't',
  userId: 'me',
  createdAt: DateTime(2026, 10, 30),
  rounds: [
    TournamentRound(roundNumber: 1, matches: [match]),
  ],
);

class _Repo extends MockZanKurdRepository {
  _Repo(this.bracket);
  final TournamentBracket bracket;
  @override
  String? get currentUserId => 'me';
  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => bracket;
  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 20,
  }) async => tournamentStandingsFromBracket(bracket);
}

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true}),
  );
  for (final c in [
    (
      name: 'ikisi de oynamadı',
      one: false,
      two: false,
      expired: false,
      played: 0,
      unplayed: 2,
      waiting: 1,
    ),
    (
      name: 'biri 0 gönderdi',
      one: true,
      two: false,
      expired: false,
      played: 1,
      unplayed: 1,
      waiting: 1,
    ),
    (
      name: 'ikisi gönderdi',
      one: true,
      two: true,
      expired: false,
      played: 2,
      unplayed: 0,
      waiting: 0,
    ),
    (
      name: 'süre doldu',
      one: true,
      two: false,
      expired: true,
      played: 1,
      unplayed: 1,
      waiting: 0,
    ),
  ]) {
    test(
      'T2 ${c.name}: gönderim modelde kayboluyordu; yalnız pozitif skor sınanmıştı',
      () {
        final match = _match(one: c.one, two: c.two, expired: c.expired);
        final saved = TournamentMatch.fromJson(
          match.copyWith(playerOneName: 'Roj').toJson(),
        );
        expect(saved.hasPlayerOneSubmitted, c.one);
        expect(saved.hasPlayerTwoSubmitted, c.two);
        expect(saved.bothSubmitted, c.one && c.two);
        expect(saved.isForfeit, c.expired);
        final standings = tournamentStandingsFromBracket(_bracket(saved));
        expect(
          standings.singleWhere((s) => s.playerId == 'me').hasSubmitted,
          c.one,
        );
        expect(
          standings.singleWhere((s) => s.playerId == 'other').hasSubmitted,
          c.two,
        );
        expect(saved.toJson()['p1_submitted_at'], c.one ? _sent : null);
        expect(saved.toJson()['p2_submitted_at'], c.two ? _sent : null);
        expect(saved.toJson().containsKey('p1_submitted_at'), isTrue);
      },
    );
    for (final width in [320.0, 402.0]) {
      testWidgets(
        'T2 ${c.name} $width: 0 puan oynanmadı sanılıyordu; RPC zamanı yoktu',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            testShell(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: TournamentBracketWidget(
                      bracket: _bracket(
                        _match(one: c.one, two: c.two, expired: c.expired),
                      ),
                      userId: 'me',
                      ku: false,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Oynadı · 0'), findsNWidgets(c.played));
          expect(find.text('Henüz oynamadı'), findsNWidgets(c.unplayed));
          expect(find.text('Sonuç bekleniyor'), findsNWidgets(c.waiting));
          if (c.expired) expect(find.text('Hükmen geçti'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'T2 eski RPC sıfır skoru oynanmadı sanılıyordu; eksik ve null aynıydı',
    () {
      final legacy = TournamentMatch.fromJson(const {
        'playerOneScore': 0,
        'playerTwoScore': 45,
      });
      expect(legacy.hasPlayerOneSubmitted, isNull);
      expect(legacy.hasPlayerTwoSubmitted, isTrue);
      expect(legacy.toJson().containsKey('p1_submitted_at'), isFalse);
      final malformed = TournamentMatch.fromJson(const {
        'p1_submitted_at': 'bozuk',
      });
      expect(malformed.hasPlayerOneSubmitted, isNull);
      final flag = TournamentMatch.fromJson(const {
        'p1_submitted': true,
        'p2_submitted': false,
      });
      final restored = TournamentMatch.fromJson(flag.toJson());
      expect(restored.hasPlayerOneSubmitted, isTrue);
      expect(restored.hasPlayerTwoSubmitted, isFalse);
    },
  );

  test(
    'T2 sıralama tur atlayınca gönderimi unutuyordu; sadece toplam skor sınanmıştı',
    () {
      final first = _match(one: true, two: true);
      final finalMatch = _match().copyWith(id: 'final', playerTwoId: 'third');
      final bracket = _bracket(first).copyWith(
        rounds: [
          TournamentRound(roundNumber: 1, matches: [first]),
          TournamentRound(roundNumber: 2, matches: [finalMatch]),
        ],
      );
      final standings = tournamentStandingsFromBracket(bracket);
      expect(
        standings.singleWhere((s) => s.playerId == 'me').hasSubmitted,
        isTrue,
      );
      expect(
        standings.singleWhere((s) => s.playerId == 'third').hasSubmitted,
        isFalse,
      );
      expect(standings.singleWhere((s) => s.playerId == 'me').totalScore, 0);
      final roundTrip = TournamentStandings.fromJson(
        standings.first.copyWith(rank: 1).toJson(),
      );
      expect(roundTrip.hasSubmitted, standings.first.hasSubmitted);
    },
  );

  for (final c in [
    (
      name: 'iki gönderim ama henüz kapanmadı',
      match: _match(one: true, two: true).copyWith(status: 'active'),
      text: '0 – 0',
    ),
    (
      name: 'süresi doldu kimse göndermedi',
      match: _match(expired: true),
      text: 'Süre doldu · oynayan yok',
    ),
    (
      name: 'ikinci taraf sıfırla hükmen geçti',
      match: _match(two: true, expired: true).copyWith(winnerId: 'other'),
      text: 'Hükmen geçti',
    ),
    (
      name: 'bay geçiş oynanmış maç değildir',
      match: _match(expired: true).copyWith(playerTwoId: '', winnerId: 'me'),
      text: 'Hükmen geçti',
    ),
  ]) {
    testWidgets(
      'T2 ${c.name}: sahte bekleme/0–0 görünüyordu; gönderim alanı sınanmıyordu',
      (tester) async {
        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: TournamentBracketWidget(
                bracket: _bracket(c.match),
                userId: 'me',
                ku: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(c.text), findsOneWidget);
        expect(find.text('Sonuç bekleniyor'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'T2 iki gönderimde rakip bekleniyordu; aktif çift gönderim hiç sınanmamıştı',
    (tester) async {
      await tester.pumpWidget(
        testShell(
          child: TournamentScreen(
            repository: _Repo(
              _bracket(_match(one: true, two: true).copyWith(status: 'active')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('İki sonuç da gönderildi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tournament-awaiting-deadline')),
        findsNothing,
      );
      expect(find.text('Sonuç bekleniyor'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'T2 cihaz değişince 0 puana Başlat dönüyordu; yerel kayıt kusuru gizliyordu',
    (tester) async {
      await tester.pumpWidget(
        testShell(
          child: TournamentScreen(
            repository: _Repo(_bracket(_match(one: true))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tournament-awaiting-opponent')),
        findsOneWidget,
      );
      expect(find.text('Oynadı · 0'), findsWidgets);
      expect(find.text('Henüz oynamadı'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
