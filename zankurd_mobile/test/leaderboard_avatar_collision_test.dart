// 2026-07-23 canlı UX denetimi M25b: podyumdaki oyuncular aynı ada bağlı
// hash rengine düşerse ("Diyar", "Newroz", "Sara" — avatarNamePalette'te
// aynı dilime hash'lenir, bkz. test/avatar_color_collision_test.dart)
// round-robin ile farklı renk atanmalı. Bu dosya gerçek LeaderboardScreen
// ağacında bu çözümün uygulandığını doğrular.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

import 'support/widget_test_helpers.dart';

class _CollidingNamesRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    // Hiçbiri colorHex seçmemiş — üçü de hash fallback'ine düşer ve
    // Diyar/Newroz/Sara aynı palet dilimine hash'lenir.
    return const [
      LeaderboardEntry(
        playerId: 'p1',
        displayName: 'Diyar',
        totalScore: 900,
        bestStreak: 5,
        roomsPlayed: 10,
        rank: 1,
      ),
      LeaderboardEntry(
        playerId: 'p2',
        displayName: 'Newroz',
        totalScore: 800,
        bestStreak: 4,
        roomsPlayed: 9,
        rank: 2,
      ),
      LeaderboardEntry(
        playerId: 'p3',
        displayName: 'Sara',
        totalScore: 700,
        bestStreak: 3,
        roomsPlayed: 8,
        rank: 3,
      ),
    ];
  }

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

void main() {
  testWidgets(
    'podyumda hash çakışan üç oyuncu farklı avatar rengi alır',
    (tester) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: LeaderboardScreen(repository: _CollidingNamesRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatars = tester.widgetList<PlayerAvatar>(
        find.byType(PlayerAvatar),
      );
      final colorsByName = <String, Color?>{
        for (final a in avatars)
          if (a.displayName != null) a.displayName!: a.colorOverride,
      };

      expect(colorsByName['Diyar'], isNotNull);
      expect(colorsByName['Newroz'], isNotNull);
      expect(colorsByName['Sara'], isNotNull);
      expect(
        {colorsByName['Diyar'], colorsByName['Newroz'], colorsByName['Sara']}
            .length,
        3,
        reason:
            'Diyar/Newroz/Sara aynı hash dilimine düşüyor; round-robin '
            'çözümü olmadan üçü de aynı rengi alırdı.',
      );
    },
  );
}
