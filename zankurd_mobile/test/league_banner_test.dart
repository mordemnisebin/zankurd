// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';

class _TestLeagueRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return const [
      LeaderboardEntry(
        rank: 1,
        playerId: 'm1',
        displayName: 'Rojda',
        totalScore: 8420,
        bestStreak: 11,
        roomsPlayed: 14,
      ),
    ];
  }
}

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // Lig 2026-09-27'den beri bayrakla kapalı (kWeeklyLeagueEnabled): az
  // oyuncuyla herkes "Bronz lig"de kalıyordu. Bayrak açılınca bu test yine
  // koşar; kapalıyken ikinci test bandın hiç çizilmediğini denetler.
  testWidgets(
    'haftalık görünümde lig bandı görünür',
    skip: !kWeeklyLeagueEnabled,
    (tester) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _shell(LeaderboardScreen(repository: _TestLeagueRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('league-banner')), findsOneWidget);
      expect(find.text('Bronz lig'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lig kapalıyken haftalık görünümde bant çizilmez',
    skip: kWeeklyLeagueEnabled,
    (tester) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _shell(LeaderboardScreen(repository: _TestLeagueRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('league-banner')), findsNothing);
      expect(find.text('Bronz lig'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
