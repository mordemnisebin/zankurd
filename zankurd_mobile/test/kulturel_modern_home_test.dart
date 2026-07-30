import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/widgets/app_row_card.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/colorful_action_card.dart';
import 'package:zankurd_mobile/src/widgets/zana_daily_card.dart';

// Ana sayfa (2026-07-24 yenilemesi): ekran tek bir soruyu yanıtlar — "şimdi
// ne yapmalıyım?". Karo ızgarası kaldırıldı; sıra bugünün görevi → öğrenme
// yolları → yarış geçişi → günlük görevler.
Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: child,
  ),
);

void main() {
  testWidgets('Ana sayfa tek birincil görev ve destek satırlarını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
          onOpenCategories: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Tek birincil eylem.
    expect(find.byType(TodayTaskCard), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task-start')), findsOneWidget);

    // Destek satırları tek tip kart bileşenini kullanır.
    expect(find.byKey(const ValueKey('home-duel-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-topic-picker')), findsOneWidget);
    expect(find.byType(AppRowCard), findsWidgets);
    expect(find.byType(DailyMissionsCard), findsOneWidget);

    // Kalabalık eski bloklar yok: karo ızgarası, teaser kartları, kopya
    // "Yarış"/"Kategoriler" girişleri.
    expect(find.byType(ColorfulActionCard), findsNothing);
    expect(find.byType(ZanaDailyCard), findsNothing);
    expect(find.bySemanticsLabel('Moda tarî/ronahî'), findsOneWidget);
  });

  testWidgets('öğrenme yolları ve yarış geçişi farklı hedeflere gider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var lessons = 0;
    var categories = 0;
    var play = 0;

    await tester.pumpWidget(
      _wrap(
        HomeScreen(
          repository: MockZanKurdRepository(),
          displayName: 'Zelal',
          scrollController: ScrollController(),
          onOpenLearning: () => lessons++,
          onOpenCategories: () => categories++,
          onOpenPlay: () => play++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('home-learning-path')));
    await tester.tap(find.byKey(const ValueKey('home-topic-picker')));
    await tester.tap(find.byKey(const ValueKey('home-play-handoff')));

    expect((lessons, categories, play), (1, 1, 1));
  });

  testWidgets('ekranda yalnız bir gradyanlı birincil buton var', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
          onOpenCategories: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Gradyan "buraya bas" demektir; ekran başına bir tane.
    final gradientBoxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration && decoration.gradient != null;
        })
        .length;
    expect(gradientBoxes, lessThanOrEqualTo(1));
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(844, 390),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Ana sayfa ${size.width.toInt()}x${size.height.toInt()} taşmaz',
      (tester) async {
        tester.view.physicalSize = size;
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
              onOpenCategories: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('eski teaser ve karo sınıfları home içinde yok', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(source, isNot(contains('class _PlayHubTeaser')));
    expect(source, isNot(contains('class _CategoryEntry')));
    expect(source, isNot(contains('class _DailyLessonHero')));
    expect(source, isNot(contains('HomeLobbyGrid')));
    expect(source, contains('TodayTaskCard'));
  });
}
