/// Haftalık lig görünümü bekçisi (Duolingo tarzı küme).
///
/// ## Kusur (kurul bulgusu)
///
/// Tek global sıralama yeni oyuncuyu bin puanlık liderlerin altında bırakır;
/// bırakma isteği doğurur. Lig, oyuncuyu yakın puanlı küçük bir kümeye koyar.
///
/// ## Niçin sessiz kalırdı
///
/// Lig sunucuda yoksa (göç uygulanmamış) ya da bölge sınırları yanlışsa
/// ekran çökmez, yalnız yanlış kişiyi "düşüyor" diye boyar ya da bölgeyi
/// yalnız renkle anlatır. Bu dosya sözleşmeyi sabitler: sunucu yoksa segment
/// gizlenir (eski dört segment aynen kalır), varsa Lig İLK ve varsayılandır,
/// bölgeler yazıyla da işaretlidir, dar ekranda ve %200 yazıda taşma yoktur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/weekly_league.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

WeeklyLeague _league({
  int tier = 2,
  bool joined = true,
  int size = 12,
  int myRank = 6,
  LeagueResult? result,
  int secondsLeft = 3 * 86400 + 5 * 3600,
}) {
  final promote = size < 4 ? 0 : (size ~/ 3).clamp(0, 5);
  return WeeklyLeague(
    tier: tier,
    joined: joined,
    secondsLeft: secondsLeft,
    cohortSize: joined ? size : 0,
    promoteCount: tier >= 4 ? 0 : promote,
    demoteCount: tier <= 0 ? 0 : promote,
    myRank: joined ? myRank : null,
    myScore: joined ? 300 : 0,
    lastResult: result,
    members: joined
        ? [
            for (var i = 1; i <= size; i++)
              LeagueMember(
                rank: i,
                playerId: i == myRank ? 'user' : 'p$i',
                displayName: i == myRank
                    ? 'Rojhat'
                    : 'Oyuncu çok uzun bir ad numara $i',
                score: 1000 - i * 50,
                isMe: i == myRank,
              ),
          ]
        : const [],
  );
}

class _LeagueRepo extends MockZanKurdRepository {
  _LeagueRepo(this.league, {this.supported = true});

  final WeeklyLeague? league;
  final bool supported;
  int acks = 0;
  int fetches = 0;

  @override
  bool get leagueSupported => supported;

  @override
  Future<WeeklyLeague?> getMyLeague() async {
    fetches++;
    return league;
  }

  @override
  Future<void> ackLeagueResult() async => acks++;
}

Future<void> _pump(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  Size size = const Size(375, 667),
  double textScale = 1.0,
  bool ku = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: LeaderboardScreen(repository: repo)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('model', () {
    test('bölge sınırları: ilk N çıkar, son N düşer', () {
      final l = _league(size: 30);
      expect(l.promoteCount, 5);
      expect(l.inPromotionZone(5), isTrue);
      expect(l.inPromotionZone(6), isFalse);
      expect(l.inDemotionZone(25), isFalse);
      expect(l.inDemotionZone(26), isTrue);
      expect(l.inDemotionZone(30), isTrue);
    });

    test('Efsane çıkmaz, Bronz düşmez', () {
      expect(_league(tier: 4).inPromotionZone(1), isFalse);
      expect(_league(tier: 0).inDemotionZone(12), isFalse);
    });

    test('JSON: sunucu yanıtı ayrıştırılır, kademe sınırlanır', () {
      final l = WeeklyLeague.fromJson({
        'tier': 9,
        'joined': true,
        'seconds_left': 100,
        'cohort_size': 2,
        'promote_count': 0,
        'demote_count': 0,
        'my_rank': 2,
        'my_score': 40,
        'members': [
          {'rank': 1, 'player_id': 'a', 'display_name': 'A', 'score': 90},
          {
            'rank': 2,
            'player_id': 'b',
            'display_name': 'B',
            'score': 40,
            'is_me': true,
          },
        ],
        'last_result': {
          'outcome': 'promoted',
          'from_tier': 1,
          'to_tier': 2,
          'rank': 3,
        },
      });
      expect(l.tier, kLeagueTierCount - 1);
      expect(l.members.last.isMe, isTrue);
      expect(l.lastResult!.outcome, LeagueOutcome.promoted);
      expect(l.lastResult!.toTier, 2);
      expect(LeagueResult.fromJson({'outcome': 'bilinmeyen'}), isNull);
    });
  });

  group('ekran', () {
    testWidgets('Lig varsayılan segmenttir; kademe, kalan süre, bölgeler', (
      tester,
    ) async {
      await _pump(tester, _LeagueRepo(_league()));
      expect(find.byKey(const ValueKey('league-view')), findsOneWidget);
      expect(find.text('Altın Lig'), findsOneWidget);
      expect(
        find.text('Haftanın bitmesine 3 gün 5 sa'),
        findsOneWidget,
        reason: 'geri sayım',
      );
      // Segmentler: Lig, Gün, Hafta, Ay, Arkadaş.
      for (final label in ['Lig', 'Gün', 'Hafta', 'Ay', 'Arkadaş']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.byKey(const ValueKey('league-zone-promote')), findsOneWidget);
      expect(find.byKey(const ValueKey('league-zone-demote')), findsOneWidget);
      expect(find.byKey(const ValueKey('league-my-row')), findsOneWidget);
      expect(find.text('Sen'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RPC yok (null): Lig gizlenir, eski dört segment çalışır', (
      tester,
    ) async {
      await _pump(tester, _LeagueRepo(null));
      expect(find.byKey(const ValueKey('league-view')), findsNothing);
      expect(find.text('Lig'), findsNothing);
      for (final label in ['Gün', 'Hafta', 'Ay', 'Arkadaş']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('depo lig desteklemiyorsa Lig hiç çizilmez', (tester) async {
      final repo = _LeagueRepo(_league(), supported: false);
      await _pump(tester, repo);
      expect(find.text('Lig'), findsNothing);
      expect(repo.fetches, 0);
    });

    testWidgets('kümeye girmemiş oyuncu: puan kazan çağrısı', (tester) async {
      await _pump(tester, _LeagueRepo(_league(joined: false, tier: 0)));
      expect(find.byKey(const ValueKey('league-not-joined')), findsOneWidget);
      expect(find.text('Bronz Lig'), findsOneWidget);
      expect(find.byKey(const ValueKey('league-my-row')), findsNothing);
    });

    testWidgets('sonuç kartı: "Altın lige yükseldin!" ve kapatınca ack', (
      tester,
    ) async {
      final repo = _LeagueRepo(
        _league(
          result: const LeagueResult(
            outcome: LeagueOutcome.promoted,
            fromTier: 1,
            toTier: 2,
            rank: 2,
          ),
        ),
      );
      await _pump(tester, repo);
      expect(find.text('Altın lige yükseldin!'), findsOneWidget);
      expect(find.text('Geçen hafta 2. oldun'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('league-result-dismiss')));
      await tester.pump();
      expect(find.byKey(const ValueKey('league-result-card')), findsNothing);
      expect(repo.acks, 1);
    });

    testWidgets('düşme sonucu metni', (tester) async {
      await _pump(
        tester,
        _LeagueRepo(
          _league(
            result: const LeagueResult(
              outcome: LeagueOutcome.demoted,
              fromTier: 2,
              toTier: 1,
            ),
          ),
        ),
      );
      expect(find.text('Gümüş lige düştün'), findsOneWidget);
    });

    testWidgets('Kurmancî: Lîg segmenti ve Lîga Zêr', (tester) async {
      await _pump(tester, _LeagueRepo(_league()), ku: true);
      expect(find.text('Lîg'), findsWidgets);
      expect(find.text('Lîga Zêr'), findsOneWidget);
    });

    for (final (name, size, scale) in [
      ('375x667', const Size(375, 667), 1.0),
      ('320 pt', const Size(320, 640), 1.0),
      ('%200 yazı', const Size(375, 667), 2.0),
      ('320 pt + %200', const Size(320, 640), 2.0),
    ]) {
      testWidgets('taşma yok: $name', (tester) async {
        await _pump(
          tester,
          _LeagueRepo(
            _league(
              result: const LeagueResult(
                outcome: LeagueOutcome.promoted,
                fromTier: 1,
                toTier: 2,
                rank: 1,
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        // Sabit "Sen" satırı ekranda kalır.
        expect(find.byKey(const ValueKey('league-my-row')), findsOneWidget);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
