import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          for (final key in [
            'home-lessons-row',
            'home-topic-picker',
            'home-duel-row',
          ]) {
            expect(find.byKey(ValueKey(key)), findsOneWidget);
            expect(
              tester.widget<ModeCard>(find.byKey(ValueKey(key))).emphasis,
              ModeCardEmphasis.secondary,
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
          for (final key in [
            'play-hub-create-room',
            'play-hub-join-room',
            'play-hub-daily-contest',
            'play-hub-tournament',
          ]) {
            expect(find.byKey(ValueKey(key)), findsOneWidget);
            expect(
              tester.widget<ModeCard>(find.byKey(ValueKey(key))).emphasis,
              key == 'play-hub-daily-contest' || key == 'play-hub-tournament'
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
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
