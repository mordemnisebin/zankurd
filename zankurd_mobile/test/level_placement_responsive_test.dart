import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  Size size = const Size(390, 844),
}) {
  return ChangeNotifierProvider<LanguageProvider>(
    key: ValueKey('language-$isKu-$isDark-$textScale'),
    create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
    child: MaterialApp(
      key: ValueKey('$isKu-$isDark-$textScale'),
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: LevelPlacementScreen(repository: MockZanKurdRepository()),
      ),
    ),
  );
}

void _expectInside(Rect inner, Rect outer, {required String reason}) {
  expect(inner.left, greaterThanOrEqualTo(outer.left), reason: reason);
  expect(inner.top, greaterThanOrEqualTo(outer.top), reason: reason);
  expect(inner.right, lessThanOrEqualTo(outer.right), reason: reason);
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom), reason: reason);
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

  testWidgets(
    'placement actions and title stay within real bounds without clipping',
    (tester) async {
      for (final size in [const Size(390, 844), const Size(360, 800)]) {
        await tester.binding.setSurfaceSize(size);
        for (final isKu in [false, true]) {
          for (final isDark in [false, true]) {
            for (final textScale in [1.0, 1.3, 2.0]) {
              await tester.pumpWidget(
                _wrap(
                  isKu: isKu,
                  isDark: isDark,
                  textScale: textScale,
                  size: size,
                ),
              );
              await tester.pumpAndSettle();

              final title = find.text(
                isKu ? 'Asta xwe diyar bike' : 'Seviyeni belirle',
              );
              final skipLabel = isKu ? 'Paşê bike' : 'Şimdilik geç';
              final isFullLabel = size.width == 390 && textScale == 1.0;
              final action = find.byKey(
                ValueKey(
                  isFullLabel ? 'placement-skip' : 'placement-skip-compact',
                ),
              );

              expect(tester.takeException(), isNull);
              expect(find.byType(AppBar), findsOneWidget);
              expect(title, findsOneWidget);
              expect(action, findsOneWidget);

              final viewport = Offset.zero & size;
              final appBarRect = tester.getRect(find.byType(AppBar));
              final titleRect = tester.getRect(title);
              final actionRect = tester.getRect(action);
              _expectInside(titleRect, viewport, reason: 'title viewport');
              _expectInside(titleRect, appBarRect, reason: 'title appbar');
              _expectInside(actionRect, viewport, reason: 'action viewport');
              _expectInside(actionRect, appBarRect, reason: 'action appbar');

              final data = tester.getSemantics(action).getSemanticsData();
              expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
              expect(data.label, contains(skipLabel));
              expect(actionRect.width, greaterThanOrEqualTo(44));
              expect(actionRect.height, greaterThanOrEqualTo(44));

              if (isFullLabel) {
                final textFinder = find.descendant(
                  of: action,
                  matching: find.text(skipLabel),
                );
                expect(textFinder, findsOneWidget);
                final paragraph = tester.renderObject<RenderParagraph>(
                  textFinder,
                );
                expect(paragraph.didExceedMaxLines, isFalse);
                final painter = TextPainter(
                  text: paragraph.text,
                  textDirection: Directionality.of(tester.element(textFinder)),
                  textScaler: MediaQuery.textScalerOf(
                    tester.element(textFinder),
                  ),
                )..layout();
                expect(
                  paragraph.textSize.width,
                  greaterThanOrEqualTo(painter.width - 0.5),
                  reason: 'full skip label must not be clipped',
                );
                final textRect = tester.getRect(textFinder);
                _expectInside(textRect, actionRect, reason: 'skip text');
              }
            }
          }
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
