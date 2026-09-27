import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/mode_card.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

Widget _homeShell({required bool isKu, required bool isDark}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
      ),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(
      key: ValueKey('home-$isKu-$isDark'),
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: HomeScreen(
        repository: MockZanKurdRepository(),
        onOpenLearning: () async {},
        onOpenPlay: () {},
      ),
    ),
  );
}

Widget _playShell({required bool isKu, required bool isDark}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
      ),
    ],
    child: MaterialApp(
      key: ValueKey('play-$isKu-$isDark'),
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: PlayHubScreen(repository: MockZanKurdRepository()),
    ),
  );
}

BoxDecoration _modeDecoration(WidgetTester tester, String key) {
  final ink = tester.widget<Ink>(
    find
        .descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Ink))
        .first,
  );
  return ink.decoration! as BoxDecoration;
}

void _expectActionSemantics(WidgetTester tester, String key) {
  final data = tester
      .getSemantics(find.byKey(ValueKey(key)))
      .getSemanticsData();
  expect(data.hasAction(ui.SemanticsAction.tap), isTrue, reason: key);
}

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

  // 2026-09-27: ana ekran tek turuncu eylem + iki kapı + konu ızgarası
  // düzenine geçti. Bekçinin koruduğu kural aynı: ekranda tek bir birincil
  // (turuncu) eylem vardır, diğer yollar erişilebilir ama sakin kalır.
  testWidgets(
    'Home has one daily hero action and calmer accessible alternative modes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await tester.pumpWidget(_homeShell(isKu: isKu, isDark: isDark));
          await tester.pump(const Duration(seconds: 1));

          expect(
            find.byKey(const ValueKey('home-daily-task-start')),
            findsOneWidget,
          );
          _expectActionSemantics(tester, 'home-daily-task-start');

          for (final door in ['home-door-learn', 'home-door-play']) {
            final finder = find.byKey(ValueKey(door));
            expect(finder, findsOneWidget, reason: door);
            _expectActionSemantics(tester, door);
            final tile = tester.widget<HomeDoorTile>(finder);
            expect(
              tile.accent,
              isNot(AppTheme.brand),
              reason: 'Turuncu yalnız günün dersi düğmesine ayrılmış: $door',
            );
            expect(
              find.descendant(of: finder, matching: find.byType(ModeCard)),
              findsNothing,
              reason: 'Kapı ikinci bir kampanya kartı olmamalı: $door',
            );
          }

          expect(find.byKey(const ValueKey('home-topic-grid')), findsOneWidget);
          final ziman = find.byKey(const ValueKey('home-topic-Ziman'));
          await tester.ensureVisible(ziman);
          _expectActionSemantics(tester, 'home-topic-Ziman');

          // Eski dört kapılı düzenin parçaları geri gelmemeli.
          for (final legacy in [
            'home-lessons-row',
            'home-browse-categories-row',
            'home-continue-section',
            'home-duel-row',
          ]) {
            expect(find.byKey(ValueKey(legacy)), findsNothing, reason: legacy);
          }
        }
      }
    },
  );

  testWidgets(
    'Play Hub keeps quick duel primary while every other mode stays accessible without a full accent fill',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await tester.pumpWidget(_playShell(isKu: isKu, isDark: isDark));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('play-hub-quick-duel')),
            findsOneWidget,
          );
          // Turnuva `kTournamentEnabled` ile kapalı: ne kendisi ne de onu
          // açan "Daha fazla" katmanı çizilir. Bayrak açılırsa aşağıdaki
          // blok turnuva kartının altın/olay rolünü yine denetler.
          if (!kTournamentEnabled) {
            expect(find.byKey(const ValueKey('play-hub-more')), findsNothing);
            expect(
              find.byKey(const ValueKey('play-hub-tournament')),
              findsNothing,
            );
          } else {
            expect(find.byKey(const ValueKey('play-hub-more')), findsOneWidget);
            _expectActionSemantics(tester, 'play-hub-more');
          }
          for (final key in ['play-hub-create-room', 'play-hub-join-room']) {
            expect(find.byKey(ValueKey(key)), findsOneWidget);
            final decoration = _modeDecoration(tester, key);
            expect(decoration.gradient, isNull, reason: key);
            expect(
              decoration.boxShadow ?? const <BoxShadow>[],
              isEmpty,
              reason: key,
            );
            _expectActionSemantics(tester, key);
          }

          const dailyContestKey = 'play-hub-daily-contest';
          expect(find.byKey(const ValueKey(dailyContestKey)), findsOneWidget);
          final dailyContestCard = tester.widget<ModeCard>(
            find.byKey(const ValueKey(dailyContestKey)),
          );
          expect(dailyContestCard.emphasis, ModeCardEmphasis.event);
          expect(
            dailyContestCard.accent,
            AppTheme.gold,
            reason: '$dailyContestKey semantic accent role',
          );
          final dailyContestDecoration = _modeDecoration(
            tester,
            dailyContestKey,
          );
          expect(dailyContestDecoration.gradient, isNull);
          expect(
            dailyContestDecoration.boxShadow ?? const <BoxShadow>[],
            isEmpty,
          );
          _expectActionSemantics(tester, dailyContestKey);
          if (!kTournamentEnabled) {
            expect(tester.takeException(), isNull);
            continue;
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('play-hub-more')),
          );
          await tester.tap(find.byKey(const ValueKey('play-hub-more')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('play-hub-tournament')),
            findsOneWidget,
          );
          final tournamentCard = tester.widget<ModeCard>(
            find.byKey(const ValueKey('play-hub-tournament')),
          );
          expect(tournamentCard.emphasis, ModeCardEmphasis.event);
          expect(
            tournamentCard.accent,
            AppTheme.gold,
            reason: 'Turnuva prestij/ödül rolünü altınla paylaşmalı.',
          );
          final tournamentDecoration = _modeDecoration(
            tester,
            'play-hub-tournament',
          );
          expect(tournamentDecoration.gradient, isNull);
          expect(
            tournamentDecoration.boxShadow ?? const <BoxShadow>[],
            isEmpty,
          );
          _expectActionSemantics(tester, 'play-hub-tournament');
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('mode card without an action is announced as disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ModeCard(
            icon: Icons.lock_outline,
            accent: AppTheme.playGreen,
            title: 'Ode kilitli',
            subtitle: 'Sunucuya ulaşılamıyor',
            onTap: null,
            emphasis: ModeCardEmphasis.secondary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final data = tester.getSemantics(find.byType(ModeCard)).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
  });

  // "Daha fazla" katmanı yalnız turnuva bayrağı açıkken çizilir.
  testWidgets(
    'play more keeps button semantics without a nested header role',
    skip: !kTournamentEnabled,
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_playShell(isKu: false, isDark: false));
      await tester.pumpAndSettle();

      final heading = tester.widget<ScreenSectionHeading>(
        find.descendant(
          of: find.byKey(const ValueKey('play-hub-more')),
          matching: find.byType(ScreenSectionHeading),
        ),
      );
      expect(heading.semanticHeader, isFalse);
    },
  );

  testWidgets(
    'busy mode cards keep readable progress contrast and disabled semantics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const cases = [
        (emphasis: ModeCardEmphasis.secondary, accent: Color(0xFF1E4FA6)),
        (emphasis: ModeCardEmphasis.event, accent: Color(0xFF9C6300)),
        (emphasis: ModeCardEmphasis.primary, accent: Color(0xFFB31E3B)),
      ];

      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? AppTheme.dark() : AppTheme.light(),
            home: Column(
              children: [
                for (final item in cases)
                  ModeCard(
                    key: ValueKey('${item.emphasis}-$isDark'),
                    icon: Icons.bolt,
                    accent: item.accent,
                    title: '${item.emphasis} busy',
                    subtitle: 'Loading',
                    onTap: () {},
                    busy: true,
                    emphasis: item.emphasis,
                  ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        for (final item in cases) {
          final key = ValueKey('${item.emphasis}-$isDark');
          final card = find.byKey(key);
          final spinner = find.descendant(
            of: card,
            matching: find.byType(CircularProgressIndicator),
          );
          expect(spinner, findsOneWidget, reason: '$key spinner');

          final indicator = tester.widget<CircularProgressIndicator>(spinner);
          final spinnerColor = indicator.valueColor!.value;
          final expectedColor = item.emphasis == ModeCardEmphasis.primary
              ? Colors.white
              : AppColors.readableAccent(tester.element(card), item.accent);
          expect(spinnerColor, expectedColor, reason: '$key color');
          if (item.emphasis != ModeCardEmphasis.primary) {
            expect(spinnerColor, isNot(Colors.white), reason: '$key color');
          }

          final data = tester.getSemantics(card).getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue, reason: '$key role');
          expect(
            data.flagsCollection.isEnabled,
            ui.Tristate.isFalse,
            reason: '$key disabled state',
          );
          expect(
            data.hasAction(ui.SemanticsAction.tap),
            isFalse,
            reason: '$key tap disabled',
          );
          expect(tester.getRect(card).height, greaterThanOrEqualTo(48));
        }
      }
    },
  );
}
