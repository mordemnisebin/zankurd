// 7. tasarım kurulu (2026-10-20, üç denetçi): kürsü ile alt liste arasında
// kopukluk — kürsü doğrudan listenin üstüne yapışıyor, ilk üç avatar
// 4. oyuncuyla aynı çıplak çerçeveyle duruyordu.
//
// ## Niçin sessiz kalırdı
//
// Boşluk ve halka rengi bir işlev değil; kaide sırası, rakam rengi, bildir
// menüsü ve taşma testleri hepsi yeşil kalıyordu. Bekçi iki şeyi sabitler:
// ilk üç avatar altın/gümüş/bronz halka taşır (4. oyuncuda yok) ve kürsü
// ile liste arasında ince ayraç ≥ 20 px boşlukla durur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/game/avatar_frames.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => List.generate(
    5,
    (i) => LeaderboardEntry(
      rank: i + 1,
      playerId: 'p$i',
      displayName: ['Rojda', 'Baran', 'Dilan', 'Zelal', 'Hêvî'][i],
      totalScore: 8420 - i * 900,
      bestStreak: 5,
      roomsPlayed: 5,
    ),
  );

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'ilk üç avatar madalya halkalı; kürsü ile liste ayraçla ayrılır',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: Scaffold(body: LeaderboardScreen(repository: _Repo())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final expected = {
        1: frameColor(AvatarFrame.gold),
        2: frameColor(AvatarFrame.silver),
        3: frameColor(AvatarFrame.bronze),
      };
      for (final entry in expected.entries) {
        final ring = find.byKey(ValueKey('podium-medal-ring-${entry.key}'));
        expect(ring, findsOneWidget, reason: 'yer ${entry.key}');
        final deco =
            tester.widget<DecoratedBox>(ring).decoration as ShapeDecoration;
        expect((deco.shape as OutlinedBorder).side.color, entry.value);
      }
      expect(find.byKey(const ValueKey('podium-medal-ring-4')), findsNothing);

      final divider = find.byKey(const ValueKey('leaderboard-podium-divider'));
      expect(divider, findsOneWidget);
      final podium = tester.getRect(
        find.byKey(const ValueKey('leaderboard-podium')),
      );
      expect(
        tester.getRect(divider).top - podium.bottom,
        greaterThanOrEqualTo(20),
      );
    },
  );
}
