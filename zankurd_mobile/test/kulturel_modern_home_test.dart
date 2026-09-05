import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'support/widget_test_helpers.dart' show freshMockRepository;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/widgets/mode_card.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

// Ana sayfa (2026-07-24 yenilemesi): ekran tek bir soruyu yanıtlar — "şimdi
// ne yapmalıyım?". Karo ızgarası kaldırıldı; sıra bugünün görevi → öğrenme
// yolları → yarış geçişi → günlük görevler.
Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    // Ana ekran abonelik satırını `Consumer<PremiumService>` ile çiziyor;
    // uygulamada bu sağlayıcı her zaman var (bkz. `main.dart`), testin
    // kendi kapsamında da olmalı.
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: child,
  ),
);

void main() {
  setUp(() {
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.achievements.unlocked': ['first_game'],
    });
  });

  testWidgets(
    'ilk oturumda ana görev önde kalır, tamamlanınca destek kartları açılır',
    (tester) async {
      final repo = freshMockRepository();
      final refresh = ValueNotifier(0);
      addTearDown(refresh.dispose);
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(HomeScreen(repository: repo, refreshSignal: refresh)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-daily-task-start')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-duel-row')), findsNothing);
      expect(find.byType(DailyMissionsCard), findsNothing);
      expect(
        find.byKey(const ValueKey('home-learning-goal-chooser')),
        findsNothing,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList('zankurd.achievements.unlocked', [
        'first_game',
      ]);
      AchievementStore.resetInstance();
      refresh.value++;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-duel-row')), findsOneWidget);
      expect(find.byType(DailyMissionsCard), findsOneWidget);
    },
  );

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
          onOpenCategories: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Tek birincil eylem.
    expect(find.byType(TodayTaskCard), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task-start')), findsOneWidget);

    // Destek satırları tek tip kart bileşenini kullanır.
    //
    // Bileşen 2026-08-03'te `AppRowCard`tan `ModeCard`a geçti: üç mod
    // birbirinin aynı beyaz satırı olmaktan çıkıp kendi rengini ve
    // amblemini taşıyan kartlara dönüştü. Testin koruduğu şey bileşenin
    // ADI değil, sözleşmesi — modların TEK ve tutarlı bir bileşenle
    // gösterilmesi ve eski kalabalık blokların geri gelmemesi. Sözleşme
    // aynen duruyor, yalnız bileşen değişti.
    expect(find.byKey(const ValueKey('home-duel-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-topic-picker')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-browse-categories-row')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-lessons-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-path-node-1')), findsOneWidget);
    expect(find.byType(ModeCard), findsWidgets);
    expect(find.byType(DailyMissionsCard), findsOneWidget);

    // Kalabalık eski bloklar yok: karo ızgarası, teaser kartları, kopya
    // "Yarış"/"Kategoriler" girişleri.
    //
    // `ColorfulActionCard` iddiası KALDIRILDI: sınıfın kendisi
    // 2026-08-24'te silindi (ürün kodunda hiç kullanılmıyordu, yalnız
    // kendi testlerinde yaşıyordu). Var olmayan bir sınıfın ekranda
    // bulunmadığını iddia etmek gereksiz; silinmiş olması daha güçlü
    // bir garanti ve `dead_widget_guard_test` onu koruyor.
    // `ZanaDailyCard` 2026-09-02'de aynı gerekçeyle silindi.
    expect(find.bySemanticsLabel('Moda tarî/ronahî'), findsOneWidget);
  });

  testWidgets('öğrenme yolları ve yarış geçişi farklı hedeflere gider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var categories = 0;
    var play = 0;

    await tester.pumpWidget(
      _wrap(
        HomeScreen(
          repository: MockZanKurdRepository(),
          displayName: 'Zelal',
          scrollController: ScrollController(),
          onOpenCategories: () async {
            categories++;
          },
          onOpenPlay: () => play++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('home-lessons-row')));
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsOneWidget);
    await tester.tap(find.byType(ZkBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-browse-categories-row')));
    await tester.tap(find.byKey(const ValueKey('home-duel-row')));

    expect((categories, play), (1, 1));
  });

  testWidgets('ekranda birincil gradyan yalnız günün görevi kartındadır', (
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
          onOpenCategories: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Gradyan "buraya bak" demektir. Başlık şeridi bilinçli düz durur
    // (bkz. home-profile-header). Kart birincil yüzeydir; Başla düğmesi
    // onun üstünde düz beyazdır — ikinci bir gradyan CTA olmaz.
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-daily-task')),
    );
    expect((card.decoration! as BoxDecoration).gradient, isNotNull);

    final startInk = tester.widget<Ink>(
      find.descendant(
        of: find.byKey(const ValueKey('home-daily-task-start')),
        matching: find.byType(Ink),
      ),
    );
    expect((startInk.decoration! as BoxDecoration).gradient, isNull);
    expect((startInk.decoration! as BoxDecoration).color, Colors.white);
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
              onOpenCategories: () async {},
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
