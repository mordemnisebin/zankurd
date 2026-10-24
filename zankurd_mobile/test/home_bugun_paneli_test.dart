// "Bugün" paneli bekçisi (2026-10-24, sahibin kararı "Hepsi şimdi").
//
// Kusur: ana ekranda günlük döngüler ayrı ayrı sayaç taşıyordu — üst çubukta
// seri çipi, bir yerde "Günlük hedef 6/15", bir yerde "Günlük görevler 1/3".
// Oyuncu hangisinin ne olduğunu, hangisinin ödül verdiğini ayırt edemiyordu.
// Sessizdi: her sayaç kendi başına doğruydu; kusur toplamdaydı.
//
// Karar: tek panel. Üstte seri, altında TEK liste (günlük hedef de bir görev
// satırı) ve TEK özet ("Bugün 2/4 tamam"). Hedef satırının ödülü yoktur;
// görev XP'si yalnız "Ödülü al" ile verilir (callback dokunuşla çağrılır).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/widget_test_helpers.dart' show freshMockRepository;

Widget _wrap(Widget child, {String lang = 'tr', double textScale = 1}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang(lang),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider.test()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<PremiumService>(
          create: (_) => PremiumService.fallback(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

List<DailyMission> _missions() => [
  DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
  DailyMission(
    type: MissionType.useWildcard,
    target: 1,
    coinReward: 20,
    progress: 1,
    completed: true,
  ),
  DailyMission(
    type: MissionType.keepStreak,
    target: 1,
    coinReward: 30,
    progress: 1,
    completed: true,
    claimed: true,
  ),
];

Widget _card({
  required List<DailyMission> missions,
  int streak = 5,
  int? goalDone = 6,
  int? goalTarget = 15,
  void Function(DailyMission)? onClaim,
  VoidCallback? onStreakTap,
  bool isKu = false,
}) => Scaffold(
  body: SingleChildScrollView(
    child: DailyMissionsCard(
      isKu: isKu,
      missions: missions,
      streak: streak,
      onStreakTap: onStreakTap,
      goalDone: goalDone,
      goalTarget: goalTarget,
      onClaimReward: onClaim,
    ),
  ),
);

void main() {
  setUp(() {
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.achievements.unlocked': ['first_game'],
    });
    AchievementStore.resetInstance();
  });

  testWidgets('tek panel: üstte seri, altında hedef + görevler, tek özet', (
    tester,
  ) async {
    var streakTaps = 0;
    await tester.pumpWidget(
      _wrap(_card(missions: _missions(), onStreakTap: () => streakTaps++)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-missions-compact-section')),
      findsOneWidget,
    );
    expect(find.text('Bugün'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-missions-overall-progress')),
      findsOneWidget,
    );
    // 3 görev + 1 hedef = 4; 2 tamam (bitirilen 2 görev).
    expect(find.text('Bugün 2/4 tamam'), findsOneWidget);

    // Seri çipi panelin içinde ve ilk satırdan ÖNCE.
    final streak = find.byKey(const ValueKey('home-today-streak'));
    expect(streak, findsOneWidget);
    expect(find.text('5 gün'), findsOneWidget);
    final firstRow = find.byKey(
      const ValueKey('home-mission-row-answerCorrect'),
    );
    expect(
      tester.getTopLeft(streak).dy,
      lessThan(tester.getTopLeft(firstRow).dy),
    );
    await tester.tap(streak);
    expect(streakTaps, 1);
  });

  testWidgets('günlük hedef görev satırıdır: doğru ilerleme, ödülsüz', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_card(missions: _missions())));
    await tester.pumpAndSettle();

    final goalRow = find.byKey(
      const ValueKey('home-mission-row-answerCorrect'),
    );
    expect(goalRow, findsOneWidget);
    expect(
      find.descendant(of: goalRow, matching: find.text('15 doğru cevap ver')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: goalRow, matching: find.text('6 / 15')),
      findsOneWidget,
    );
    // Ödül rozeti ya da alma düğmesi yok.
    expect(
      find.descendant(of: goalRow, matching: find.textContaining('XP')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('claim-mission-answerCorrect:15')),
      findsNothing,
    );
  });

  testWidgets('hedef dolunca özet artar; hedefin ödülü hâlâ yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_card(missions: _missions(), goalDone: 15, onClaim: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bugün 3/4 tamam'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('claim-mission-answerCorrect:15')),
      findsNothing,
    );
  });

  testWidgets('günün görevi zaten "doğru cevap ver" ise hedef ikinci satır '
      'olmaz', (tester) async {
    final missions = [
      DailyMission(
        type: MissionType.answerCorrect,
        target: 10,
        coinReward: 50,
        progress: 4,
      ),
      DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25),
    ];
    await tester.pumpWidget(
      _wrap(_card(missions: missions, goalDone: 4, goalTarget: 10)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-mission-row-answerCorrect')),
      findsOneWidget,
    );
    expect(find.text('Bugün 0/2 tamam'), findsOneWidget);
  });

  testWidgets('XP yalnız "Ödülü al" dokunuşunda istenir', (tester) async {
    final claimed = <String>[];
    await tester.pumpWidget(
      _wrap(
        _card(missions: _missions(), onClaim: (m) => claimed.add(m.missionKey)),
      ),
    );
    await tester.pumpAndSettle();
    // Çizim ve özet tek başına ödül vermez.
    expect(claimed, isEmpty);
    final claim = find.byKey(const ValueKey('claim-mission-useWildcard:1'));
    expect(claim, findsOneWidget);
    await tester.tap(claim);
    expect(claimed, ['useWildcard:1']);
    // Zaten alınmış görevde düğme yok.
    expect(
      find.byKey(const ValueKey('claim-mission-keepStreak:1')),
      findsNothing,
    );
  });

  testWidgets('seri 0 iken çip çizilmez', (tester) async {
    await tester.pumpWidget(_wrap(_card(missions: _missions(), streak: 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-today-streak')), findsNothing);
  });

  testWidgets('Kurmancî metinler', (tester) async {
    await tester.pumpWidget(
      _wrap(_card(missions: _missions(), isKu: true), lang: 'ku'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Îro'), findsOneWidget);
    expect(find.text('Îro 2/4 temam bû'), findsOneWidget);
    expect(find.text('5 roj'), findsOneWidget);
  });

  for (final lang in ['tr', 'ku']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('panel 320 px, yazı x$scale, $lang taşmaz', (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _wrap(
            _card(missions: _missions(), onClaim: (_) {}, isKu: lang == 'ku'),
            lang: lang,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('ana ekranda tek panel; ayrı hedef sayacı ve üst çubuk serisi '
      'yok', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrap(
        HomeScreen(
          repository: MockZanKurdRepository(),
          displayName: 'Zelal',
          scrollController: ScrollController(),
          onOpenPlay: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DailyMissionsCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-missions-overall-progress')),
      findsOneWidget,
    );
    // Eski ayrı günlük hedef sayacı yok.
    expect(
      find.byKey(const ValueKey('home-daily-task-progress')),
      findsNothing,
    );
    expect(find.text('Günlük hedef'), findsNothing);
    expect(find.text('Günlük görevler'), findsNothing);
    // "N doğru cevap ver" en çok bir kez (günün görevi YA DA hedef satırı).
    expect(find.textContaining('doğru cevap ver'), findsOneWidget);
    // Seri çipi üst çubukta DEĞİL.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-profile-header')),
        matching: find.byKey(const ValueKey('home-today-streak')),
      ),
      findsNothing,
    );
    // Gera rojê kahramanı panelin üstünde.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-daily-task'))).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('home-missions-compact-section')),
            )
            .dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
