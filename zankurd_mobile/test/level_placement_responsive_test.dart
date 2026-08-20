import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _wrap({
  required bool isKu,
  required bool isDark,
  required double textScale,
}) {
  return ChangeNotifierProvider<LanguageProvider>(
    key: ValueKey('language-$isKu-$isDark-$textScale'),
    create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
    child: MaterialApp(
      key: ValueKey('$isKu-$isDark-$textScale'),
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: LevelPlacementScreen(repository: MockZanKurdRepository()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  testWidgets(
    'placement keeps the full text action at normal scale and a compact accessible action at large scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          for (final textScale in [1.0, 1.3, 2.0]) {
            await tester.pumpWidget(
              _wrap(isKu: isKu, isDark: isDark, textScale: textScale),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byType(AppBar), findsOneWidget);
            expect(
              find.text(isKu ? 'Asta xwe diyar bike' : 'Seviyeni belirle'),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('placement-skip')),
              textScale == 1.0 ? findsOneWidget : findsNothing,
            );
            expect(
              find.byKey(const ValueKey('placement-skip-compact')),
              textScale > 1.0 ? findsOneWidget : findsNothing,
            );

            final action = find.byKey(
              ValueKey(
                textScale == 1.0 ? 'placement-skip' : 'placement-skip-compact',
              ),
            );
            final semantics = tester.getSemantics(action).getSemanticsData();
            expect(semantics.hasAction(ui.SemanticsAction.tap), isTrue);
            expect(tester.getRect(action).width, greaterThan(0));
          }
        }
      }
    },
  );

  testWidgets('placement skip still reports null and marks the attempt', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: LevelPlacementScreen(
            repository: MockZanKurdRepository(),
            onFinished: (level) {
              expect(level, isNull);
              finished = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('placement-skip')));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    final store = await PlacementStore.load();
    expect(store.skipped, isTrue);
  });
}
