// 2026-10-28 kurul tur B (K3/K4/K5/K9/K18) bekçileri.
//
// ## Kusur
//
// Ana sayfa ve Yarış merkezi, birbiriyle yarışan dolu renkli bloklarla
// doluydu: iki dolu mod kartı, sarı çark, bordo günün turu, altın sıra bloğu;
// ana sayfada ayrıca "Bugün neye odaklanmak istersin?" ikinci bir karar
// sorusu duruyordu. "Şimdi ne yapayım?" sorusunun cevabı (turuncu düğme)
// kalabalıkta kayboluyordu. Sıralama satırı da "9 yarış · 6 seri" ikinci
// satırı ve "⋮" düğmesiyle sıra-avatar-ad-puan okumasını bozuyordu.
//
// ## Niçin sessiz kalırdı
//
// Hiçbiri derleme ya da işlev hatası değildir; yalnız tasarım borcudur ve
// bir sonraki "küçük ekleme" onu geri getirir. Bu dosya kuralı sayar:
//   * Ana ekranda ve Yarış merkezinde TEK birincil (turuncu) düğme.
//   * Ana ekranda odak bloğu (LearningGoalChooser) yok.
//   * Ana sayfa sırası: Bugünün görevi → Öğren/Yarış → Konular → Günün sözü.
//   * Sıralama satırında ikinci satır ve "⋮" yok (leaderboard_rank_list_test).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/learning_goal_chooser.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

Widget _shell(Widget home, {required bool dark, bool ku = false}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(initialLang: ku ? 'ku' : 'tr'),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider.test()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<PremiumService>(
          create: (_) => PremiumService.fallback(),
        ),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: home,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AchievementStore.resetInstance();
    SharedPreferences.setMockInitialValues({
      'zankurd.achievements.unlocked': ['first_game'],
    });
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

  final primaries = find.byWidgetPredicate(
    (w) => w is SahneButton && w.isPrimary,
  );

  for (final dark in [false, true]) {
    for (final ku in [false, true]) {
      final tag = '${dark ? 'koyu' : 'açık'} ${ku ? 'KU' : 'TR'}';

      testWidgets('ana sayfada tek turuncu birincil düğme: $tag', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _shell(
            HomeScreen(
              repository: MockZanKurdRepository(),
              onOpenLearning: () async {},
              onOpenPlay: () {},
            ),
            dark: dark,
            ku: ku,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(primaries, findsOneWidget);
        expect(find.byKey(const ValueKey('home-daily-task-start')), findsOne);
      });

      testWidgets('Yarış merkezinde tek turuncu birincil düğme: $tag', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _shell(
            PlayHubScreen(repository: MockZanKurdRepository()),
            dark: dark,
            ku: ku,
          ),
        );
        await tester.pumpAndSettle();
        expect(primaries, findsOneWidget);
        expect(
          find.byKey(const ValueKey('play-hub-quick-duel-cta')),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets('ana sayfada "Bugün neye odaklanmak istersin?" bloğu yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(
        HomeScreen(
          repository: MockZanKurdRepository(),
          onOpenLearning: () async {},
          onOpenPlay: () {},
        ),
        dark: false,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LearningGoalChooser), findsNothing);
    expect(
      find.byKey(const ValueKey('home-learning-goal-chooser')),
      findsNothing,
    );
    expect(find.textContaining('odaklanmak'), findsNothing);
  });

  testWidgets('ana sayfa sırası: görev → Öğren/Yarış → Konular → söz', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(
        HomeScreen(
          repository: MockZanKurdRepository(),
          onOpenLearning: () async {},
          onOpenPlay: () {},
        ),
        dark: false,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    double top(Finder f) => tester.getTopLeft(f).dy;
    final task = find.byKey(const ValueKey('home-daily-task'));
    final learn = find.byKey(const ValueKey('home-door-learn'));
    final play = find.byKey(const ValueKey('home-door-play'));
    final topics = find.text('Konular');
    expect(task, findsOneWidget);
    expect(top(task), lessThan(top(learn)));
    // Öğren ve Yarış aynı boyda.
    expect(tester.getSize(learn), tester.getSize(play));
    expect(top(learn), lessThan(top(topics.first)));
    final quote = find.byKey(const ValueKey('home-daily-quote'));
    if (quote.evaluate().isNotEmpty) {
      expect(top(topics.first), lessThan(top(quote)));
    }
  });
}
