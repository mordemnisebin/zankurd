// 2026-09-29 doğallık (K9): podyum yerine sıra listesi (`leaderboard-rank-list`).
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-09-29 Şahnê: sekme sayfası `ScreenSectionHeading` değil A
// iskeletidir (`SahneTabPage`); başlık oradan okunur.
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
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// loadLeaderboard çağrılarını sayan sahte depo.
class _CountingLeaderboardRepository extends MockZanKurdRepository {
  int loadCalls = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    loadCalls += 1;
    return const [
      LeaderboardEntry(
        rank: 1,
        playerId: 'm1',
        displayName: 'User1',
        totalScore: 8420,
        bestStreak: 11,
        roomsPlayed: 14,
      ),
      LeaderboardEntry(
        rank: 2,
        playerId: 'm2',
        displayName: 'User2',
        totalScore: 7200,
        bestStreak: 8,
        roomsPlayed: 10,
      ),
      LeaderboardEntry(
        rank: 3,
        playerId: 'm3',
        displayName: 'User3',
        totalScore: 6100,
        bestStreak: 6,
        roomsPlayed: 8,
      ),
      LeaderboardEntry(
        rank: 4,
        playerId: 'm4',
        displayName: 'User4',
        totalScore: 5000,
        bestStreak: 5,
        roomsPlayed: 6,
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
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  testWidgets('liderlik ortak sakin başlık gramerini ve eylemleri korur', (
    tester,
  ) async {
    final repository = _CountingLeaderboardRepository();
    await tester.pumpWidget(_shell(LeaderboardScreen(repository: repository)));
    await tester.pumpAndSettle();

    // 2026-09-29 Şahnê: sekme sayfası A iskeletidir (`SahneTabPage`).
    expect(find.byType(SahneTabPage), findsOneWidget);
    final page = tester.widget<SahneTabPage>(find.byType(SahneTabPage));
    expect(page.title, 'Sıralama');
    expect(find.byKey(const ValueKey('leaderboard-friends-button')), findsOne);
    expect(find.byKey(const ValueKey('leaderboard-refresh-button')), findsOne);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byTooltip('Yenile'), findsOneWidget);
    expect(find.bySemanticsLabel('Sıralamayı yenile'), findsOneWidget);
    // 2026-09-29 doğallık (K9): podyum yok; bütün sıralama tek liste.
    expect(find.byKey(const ValueKey('leaderboard-rank-list')), findsOne);
    expect(
      find.byKey(const ValueKey('leaderboard-rank-row-4')),
      findsOneWidget,
    );

    signal.value += 1;
    await tester.pumpAndSettle();

    expect(repository.loadCalls, greaterThan(initialCalls));
    expect(tester.takeException(), isNull);
  });

  // Regression: IndexedStack gizli sekmeleri dispose etmez; 30sn'lik sayaç
  // kullanıcı başka sekmedeyken de RPC atıyordu (gereksiz veri/pil/kota).
  // `isVisible` kapalıyken sayaç atlanır, açıkken (varsayılan) çalışır.
  testWidgets('gizli sekmede otomatik tazeleme RPC atmaz', (tester) async {
    final repository = _CountingLeaderboardRepository();
    await tester.pumpWidget(
      _shell(LeaderboardScreen(repository: repository, isVisible: () => false)),
    );
    await tester.pumpAndSettle();
    final initialCalls = repository.loadCalls;

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(
      repository.loadCalls,
      initialCalls,
      reason: 'gizli sekme 30sn sayacında RPC atmamalı',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('görünür sekmede otomatik tazeleme çalışır', (tester) async {
    final repository = _CountingLeaderboardRepository();
    await tester.pumpWidget(_shell(LeaderboardScreen(repository: repository)));
    await tester.pumpAndSettle();
    final initialCalls = repository.loadCalls;

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(
      repository.loadCalls,
      greaterThan(initialCalls),
      reason: 'görünür sekmede 30sn tazeleme sürmeli',
    );
    expect(tester.takeException(), isNull);
  });
}
