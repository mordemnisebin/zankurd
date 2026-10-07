import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

/// Altta sabitlenen "kendi satırın": sıradaysan sıran, değilsen dürüst boş
/// durum, okunamadıysa sessizlik.
///
/// ## Kusur (2026-10-01, tasarım denetimi A8)
///
/// Sabit satır yalnız dönem puanı OLAN oyuncuya çiziliyordu; puanı olmayan
/// oyuncu için ekranın altı boş kalıyordu. Oyuncu "sıralamada neredeyim?"
/// sorusuna ne cevap görüyor ne de sıralamada olmadığını öğreniyordu — ve
/// sorgu hata verince de aynı boşluk vardı: "yoksun" ile "okunamadı"
/// ayırt edilemiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Boş durum bir ÖĞE olarak yoktu, bu yüzden hiçbir test onun yokluğunu
/// yakalayamazdı; sıralama testleri yalnız satırın var olduğu yolu
/// deniyordu. Ayrıca sorgu hatası `null` döndürüp "puanım yok" ile aynı
/// görünüyordu — "yoksun" demek için hata dalının ayrı tutulması gerekti.
class _Board extends MockZanKurdRepository {
  _Board({this.mine, this.failMyRank = false});

  final LeaderboardEntry? mine;
  final bool failMyRank;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => [
    for (var i = 0; i < 5; i++)
      LeaderboardEntry(
        rank: i + 1,
        playerId: 'p$i',
        displayName: 'Oyuncu$i',
        totalScore: 5000 - i * 100,
        bestStreak: 3,
        roomsPlayed: 4,
      ),
  ];

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async {
    if (failMyRank) throw Exception('ağ');
    return mine;
  }
}

Future<void> _pump(WidgetTester tester, MockZanKurdRepository repo) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: LeaderboardScreen(repository: repo)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('listede değilsen sırası sabit satırda', (tester) async {
    await _pump(
      tester,
      _Board(
        mine: const LeaderboardEntry(
          rank: 14,
          playerId: 'user',
          displayName: 'Ez',
          totalScore: 240,
          bestStreak: 2,
          roomsPlayed: 1,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      findsOneWidget,
    );
    expect(find.text('14'), findsWidgets);
    expect(find.byKey(const ValueKey('leaderboard-not-ranked')), findsNothing);
  });

  testWidgets('dönemde puanın yoksa dürüst boş durum', (tester) async {
    await _pump(tester, _Board());
    expect(find.byKey(const ValueKey('leaderboard-my-rank-row')), findsNothing);
    expect(
      find.byKey(const ValueKey('leaderboard-not-ranked')),
      findsOneWidget,
    );
    expect(find.text('Bu sıralamada henüz yoksun.'), findsOneWidget);
    expect(find.text('Yarışa başla'), findsOneWidget);
  });

  testWidgets('puanı sıfır olan satır da "yoksun" sayılır', (tester) async {
    await _pump(
      tester,
      _Board(
        mine: const LeaderboardEntry(
          rank: 1,
          playerId: 'user',
          displayName: 'Ez',
          totalScore: 0,
          bestStreak: 0,
          roomsPlayed: 0,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('leaderboard-my-rank-row')), findsNothing);
    expect(
      find.byKey(const ValueKey('leaderboard-not-ranked')),
      findsOneWidget,
    );
  });

  testWidgets('sorgu okunamadıysa "yoksun" iddia edilmez', (tester) async {
    await _pump(tester, _Board(failMyRank: true));
    expect(find.byKey(const ValueKey('leaderboard-my-rank-row')), findsNothing);
    expect(find.byKey(const ValueKey('leaderboard-not-ranked')), findsNothing);
  });
}
