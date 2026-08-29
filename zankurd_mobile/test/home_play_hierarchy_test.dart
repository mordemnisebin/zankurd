import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:zankurd_mobile/src/widgets/mode_card.dart';

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
        onOpenCategories: () async {},
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
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

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
          expect(
            find.byKey(const ValueKey('home-lessons-row')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('home-path-node-1')),
            findsOneWidget,
          );
          _expectActionSemantics(tester, 'home-lessons-row');
          expect(find.byKey(const ValueKey('home-topic-picker')), findsNothing);
          expect(
            find.byKey(const ValueKey('home-browse-categories-row')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('home-duel-row')), findsOneWidget);
          expect(
            tester
                .widget<ModeCard>(find.byKey(const ValueKey('home-duel-row')))
                .emphasis,
            ModeCardEmphasis.secondary,
          );
          final decoration = _modeDecoration(tester, 'home-duel-row');
          expect(decoration.gradient, isNull);
          expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
          _expectActionSemantics(tester, 'home-duel-row');
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
          expect(find.byKey(const ValueKey('play-hub-more')), findsOneWidget);
          _expectActionSemantics(tester, 'play-hub-more');
          expect(
            find.byKey(const ValueKey('play-hub-tournament')),
            findsNothing,
          );
          for (final key in [
            'play-hub-create-room',
            'play-hub-join-room',
            'play-hub-daily-contest',
          ]) {
            expect(find.byKey(ValueKey(key)), findsOneWidget);
            expect(
              tester.widget<ModeCard>(find.byKey(ValueKey(key))).emphasis,
              key == 'play-hub-daily-contest'
                  ? ModeCardEmphasis.event
                  : ModeCardEmphasis.secondary,
              reason: key,
            );
            final decoration = _modeDecoration(tester, key);
            expect(decoration.gradient, isNull, reason: key);
            expect(
              decoration.boxShadow ?? const <BoxShadow>[],
              isEmpty,
              reason: key,
            );
            _expectActionSemantics(tester, key);
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
          expect(
            tester
                .widget<ModeCard>(
                  find.byKey(const ValueKey('play-hub-tournament')),
                )
                .emphasis,
            ModeCardEmphasis.event,
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

  testWidgets(
    'busy mode cards keep readable progress contrast and disabled semantics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 300));
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
          expect(tester.getRect(card).height, greaterThanOrEqualTo(44));
        }
      }
    },
  );
}
