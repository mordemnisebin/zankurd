/// 2026-09-30: sabitlenen "benim sıram" satırı artık DÖNEM (Gün/Hafta/Ay)
/// puanını gösterir.
///
/// ## Kusur
///
/// Liste `get_leaderboard(p_days)` ile yalnız biten çevrimiçi odalardan,
/// dönem süzgeciyle geliyordu; sabit satır ise `getPlayerStats()` ile
/// `leaderboard_entries` görünümünden okunuyordu — orada `total_score =
/// profiles.xp` (TOPLAM XP) ve sıra tüm profiller içinde. Aynı ekranda iki
/// ayrı sayı aynı etiketle sunuluyordu ve oyuncunun dönem puanı yokken bile
/// satır çizilebiliyordu.
///
/// ## Bekçi
///
/// * Satır, `getMyLeaderboardRank(period)` sonucunu çizer: dönem puanı
///   görünür, toplam XP görünmez.
/// * Dönem değişince satır YENİDEN o dönemle sorulur (Gün ≠ Hafta ≠ Ay).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

LeaderboardEntry _entry(
  int rank,
  String name,
  int score, {
  required int rooms,
  required int streak,
}) => LeaderboardEntry(
  rank: rank,
  playerId: 'user',
  displayName: name,
  totalScore: score,
  bestStreak: streak,
  roomsPlayed: rooms,
);

/// Dönem bağımsız ilk 10 + oyuncunun dönem/karşıt değerleri.
///
/// `ranks` dönem -> o dönemin sabit satırı. Oyuncu listede DEĞİL
/// (`playerId: 'other-*'`), yani sabit satır her zaman çizilir.
class _PeriodRepo extends MockZanKurdRepository {
  _PeriodRepo({required this.ranks, this.xp});

  final Map<LeaderboardPeriod, LeaderboardEntry> ranks;

  /// `getPlayerStats` (toplam XP) — satırı BESLEMEMELİ.
  final LeaderboardEntry? xp;

  /// Depoya hangi dönemlerle soruldu (sırayla).
  final requestedPeriods = <LeaderboardPeriod>[];

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => List.generate(
    10,
    (i) => LeaderboardEntry(
      playerId: 'other-$i',
      displayName: 'Oyuncu ${i + 1}',
      totalScore: 5000 - i * 100,
      bestStreak: 5,
      roomsPlayed: 10,
      rank: i + 1,
    ),
  );

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => xp;

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async {
    requestedPeriods.add(period);
    return ranks[period];
  }
}

Future<void> _pump(WidgetTester tester, MockZanKurdRepository repo) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: LeaderboardScreen(repository: repo)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sabit satır dönem puanını gösterir, toplam XP göstermez', (
    tester,
  ) async {
    final repo = _PeriodRepo(
      ranks: {
        LeaderboardPeriod.weekly: _entry(
          12,
          'Rojhat',
          210,
          rooms: 3,
          streak: 2,
        ),
      },
      // `leaderboard_entries`/`profiles.xp: aynı ekranda ikinci bir sayı.
      xp: _entry(47, 'Rojhat', 1143, rooms: 40, streak: 9),
    );
    await _pump(tester, repo);

    expect(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      findsOneWidget,
      reason: 'ilk 10 dışında kalan oyuncunun sabit satırı çizilmeli',
    );
    // Dönem puanı ve döneme ait diğer sayılar satırda.
    expect(find.text('210'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3 yarış · 2 seri'), findsOneWidget);
    // Toplam XP satıra sızmamalı.
    expect(find.text('1143'), findsNothing);
    expect(find.text('40 yarış · 9 seri'), findsNothing);
    expect(repo.requestedPeriods, [LeaderboardPeriod.weekly]);
  });

  testWidgets('dönem değişince satır yeni dönemle yeniden sorulur', (
    tester,
  ) async {
    final repo = _PeriodRepo(
      ranks: {
        LeaderboardPeriod.weekly: _entry(
          12,
          'Rojhat',
          210,
          rooms: 3,
          streak: 2,
        ),
        LeaderboardPeriod.daily: _entry(15, 'Rojhat', 60, rooms: 1, streak: 1),
      },
      xp: _entry(47, 'Rojhat', 1143, rooms: 40, streak: 9),
    );
    await _pump(tester, repo);
    expect(find.text('210'), findsOneWidget);

    // Varsayılan sekme Hafta (başlangıç indeksi 1); Gün'e geç.
    await tester.tap(find.text('Gün'));
    await tester.pumpAndSettle();

    expect(repo.requestedPeriods, [
      LeaderboardPeriod.weekly,
      LeaderboardPeriod.daily,
    ]);
    expect(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      findsOneWidget,
    );
    expect(find.text('60'), findsOneWidget);
    // Sıra rakamı listedeki 1..10 aralığının dışında: 15 yalnız sabit
    // satırda olabilir.
    expect(find.text('15'), findsOneWidget);
    expect(find.text('1 yarış · 1 seri'), findsOneWidget);
    expect(find.text('210'), findsNothing);
    expect(find.text('1143'), findsNothing);
  });

  testWidgets('dönemde puanı yoksa satır hiç çizilmez', (tester) async {
    // RPC sonucu boş: oyuncu bu dönemde biten çevrimiçi odadan puan
    // almamış. Topam XP (getPlayerStats) satırı geri getirmemeli.
    final repo = _PeriodRepo(
      ranks: const {},
      xp: _entry(47, 'Rojhat', 1143, rooms: 40, streak: 9),
    );
    await _pump(tester, repo);

    expect(find.byKey(const ValueKey('leaderboard-my-rank-row')), findsNothing);
    expect(find.text('1143'), findsNothing);
  });
}
