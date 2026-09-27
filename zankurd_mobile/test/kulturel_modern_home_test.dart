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
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

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
      // İlk oturum: yol gösterici var, görev/ilerleme kalabalığı yok.
      // Yarış kapısı ise baştan görünür — uygulamanın ikinci yüzü.
      expect(find.byKey(const ValueKey('home-first-steps')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-door-play')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-progress-summary')), findsNothing);
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
      expect(find.byKey(const ValueKey('home-first-steps')), findsNothing);
      expect(
        find.byKey(const ValueKey('home-progress-summary')),
        findsOneWidget,
      );
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

    // Üst kimlik alanı artık kart değildir; ekranın kendi sakin başlığıdır.
    expect(
      tester.widget(find.byKey(const ValueKey('home-profile-header'))),
      isA<Padding>(),
    );

    // Tek birincil eylem.
    expect(find.byType(TodayTaskCard), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task-start')), findsOneWidget);

    // Hero'nun altında iki kapı (öğren / yarış) ve bütün konuların ızgarası.
    // Eski dört kapılı "Öğrenme yolları" düzeni geri gelmemeli.
    expect(find.byKey(const ValueKey('home-door-learn')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-door-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-topic-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-topic-picker')), findsNothing);
    expect(find.byKey(const ValueKey('home-lessons-row')), findsNothing);
    expect(find.byKey(const ValueKey('home-duel-row')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-browse-categories-row')),
      findsNothing,
    );
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
    // Tema düğmesi başlıktan kalktı (güneş simgesi ayar çarkıyla
    // karışıyordu); tema Ayarlar'da. Dil düğmesi yerinde.
    expect(find.bySemanticsLabel('Moda tarî/ronahî'), findsNothing);
    expect(find.byKey(const ValueKey('home-language-toggle')), findsOneWidget);
  });

  testWidgets('öğren, yarış ve konu kapıları ayrı hedeflere gider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var learn = 0;
    var play = 0;
    String? topic;

    await tester.pumpWidget(
      _wrap(
        HomeScreen(
          repository: MockZanKurdRepository(),
          displayName: 'Zelal',
          scrollController: ScrollController(),
          onOpenLearning: () async {
            learn++;
          },
          onOpenCategories: () async {},
          onOpenCategory: (category) async {
            topic = category;
          },
          onOpenPlay: () => play++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('home-door-learn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-door-play')));
    await tester.pumpAndSettle();
    final ziman = find.byKey(const ValueKey('home-topic-Ziman'));
    await tester.ensureVisible(ziman);
    await tester.pumpAndSettle();
    await tester.tap(ziman);
    await tester.pumpAndSettle();

    expect((learn, play, topic), (1, 1, 'Ziman'));
  });

  testWidgets('günün görevi ana sahne hero tasarımını korur', (tester) async {
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

    // Design 2.0'da günün görevi ekranın tek baskın sahnesidir. Derin yeşil
    // hero arka planı hiyerarşiyi taşır; turuncu yalnız ana CTA'da kalır.
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-daily-task')),
    );
    final cardDecoration = card.decoration! as BoxDecoration;
    expect(cardDecoration.gradient, isA<LinearGradient>());
    final gradient = cardDecoration.gradient! as LinearGradient;
    expect(gradient.colors, contains(AppTheme.culturalBrandBg));
    expect(cardDecoration.border, isNull);

    final startMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const ValueKey('home-daily-task-start')),
        matching: find.byType(Material),
      ),
    );
    expect(startMaterial.color, AppTheme.brand);
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
