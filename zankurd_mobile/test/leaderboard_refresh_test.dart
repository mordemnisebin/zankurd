import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// loadLeaderboard çağrılarını sayan sahte depo.
class _CountingLeaderboardRepository extends MockZanKurdRepository {
  int loadCalls = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    loadCalls += 1;
    return super.loadLeaderboard(limit: limit, period: period);
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
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  // Regression: AppShell sekmeleri IndexedStack içinde canlı kalır; initState
  // sekme geçişinde yeniden çalışmaz. refreshSignal tetiklenince liderlik
  // tablosu yeniden yüklenmeli, yoksa skor güncellemeleri bayat kalır.
  testWidgets('refreshSignal tetiklenince liderlik tablosu yeniden yüklenir', (
    tester,
  ) async {
    final repository = _CountingLeaderboardRepository();
    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);

    await tester.pumpWidget(
      _shell(LeaderboardScreen(repository: repository, refreshSignal: signal)),
    );
    await tester.pumpAndSettle();
    final initialCalls = repository.loadCalls;
    expect(initialCalls, greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('leaderboard-refresh-button')), findsOne);
    expect(find.byKey(const ValueKey('leaderboard-podium')), findsOne);
    expect(
      find.byKey(const ValueKey('leaderboard-rank-row-4')),
      findsOneWidget,
    );

    signal.value += 1;
    await tester.pumpAndSettle();

    expect(repository.loadCalls, greaterThan(initialCalls));
    expect(tester.takeException(), isNull);
  });
}
