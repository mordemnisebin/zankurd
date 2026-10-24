// 2026-10-20 TASARIM KURULU (tur 6b): podyumda avatar kaideden ayrı durur.
//
// ## Kusur
//
// Kurul, kürsüde (220/221) harf avatarlarının kaide kutularının üst
// kenarına bindiğini ve sıra rakamıyla iç içe göründüğünü bildirdi.
// Ana ajanın ekran turunda bu düzen zaten ayrıktı (avatar kaidenin 8 pt
// üstünde); yine de bu sözleşme hiçbir testte yazılı değildi.
//
// ## Niçin sessiz kalırdı
//
// `leaderboard_top_three_test` sırayı (2·1·3), kaide yüksekliğini ve
// rakamları ölçer; avatarın kaideye hiç değmediğini ölçmez. Avatar ya da
// çerçeve büyüyüp aradaki 8 pt'yi yerse (taşan değil, binen bir görünüm)
// hiçbir test kırılmazdı. Sözleşme: avatar altı ile kaide üstü arası en az
// 8 pt, taç 1. avatarın üstünde ortalı, kaide yükseklikleri 1 > 2 > 3.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/widgets/leaderboard_podium.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('avatar kaideden 8 pt ayrı, taç ortalı, 1 > 2 > 3', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final entries = [
      for (var i = 0; i < 3; i++)
        LeaderboardEntry(
          rank: i + 1,
          playerId: 'p$i',
          displayName: ['Rojda', 'Baran', 'Dilan'][i],
          totalScore: 8420 - i * 700,
          bestStreak: 5,
          roomsPlayed: 9,
        ),
    ];
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LeaderboardPodium(
              entries: entries,
              isKu: false,
              selfId: null,
              colorOverrides: const {},
              onReport: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final heights = <double>[];
    for (var rank = 1; rank <= 3; rank++) {
      final col = find.byKey(ValueKey('leaderboard-rank-row-$rank'));
      final avatar = tester.getRect(
        find.descendant(of: col, matching: find.byType(PlayerAvatar)),
      );
      final pedestal = tester.getRect(
        find
            .descendant(
              of: col,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is ShapeDecoration &&
                    (w.decoration as ShapeDecoration).color != null,
              ),
            )
            .first,
      );
      expect(
        pedestal.top - avatar.bottom,
        greaterThanOrEqualTo(8),
        reason: 'sıra $rank: avatar kaideye binmemeli',
      );
      heights.add(pedestal.height);
      if (rank == 1) {
        final crown = tester.getRect(
          find.descendant(of: col, matching: find.byType(SahneGlyph)),
        );
        expect(crown.bottom, lessThanOrEqualTo(avatar.top));
        expect(crown.center.dx, closeTo(avatar.center.dx, 0.5));
      }
    }
    expect(heights[0], greaterThan(heights[1]));
    expect(heights[1], greaterThan(heights[2]));
  });
}
