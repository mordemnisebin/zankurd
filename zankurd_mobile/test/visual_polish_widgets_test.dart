// 2026-10-19 sadeleşme: kart geometrisi artık YUVARLAK dikdörtgendir
// (yarıçap 16; eskiden L pahı). Bu dosyadaki ilk test bu yüzden
// `RoundedRectangleBorder` bekler; öteki testler (gölge, kontrast) aynı.
import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final brighter = math.max(firstLuminance, secondLuminance);
  final darker = math.min(firstLuminance, secondLuminance);
  return (brighter + 0.05) / (darker + 0.05);
}

void main() {
  test('light and dark themes keep one card geometry language', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      // 2026-10-19 sadeleşme: kartlar iki temada da aynı yuvarlak köşeyi
      // (16) taşır. (Şahnê 2026-09-29: eskiden kesik köşe, 45° pah.)
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;

      expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
    }
  });

  testWidgets('panel elevation stays subtle and present in both themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      late List<BoxShadow> shadows;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              shadows = AppTheme.cardShadow(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(shadows, hasLength(1));
      expect(shadows.single.blurRadius, greaterThan(0));
      expect(shadows.single.blurRadius, lessThanOrEqualTo(18));
      expect(shadows.single.color.a, lessThanOrEqualTo(0.18));
    }
  });

  testWidgets('panel exposes one named tap action to assistive technology', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppPanel(
            semanticLabel: 'Günün görevi',
            onTap: () => taps++,
            child: const Text('Beş soru çöz'),
          ),
        ),
      ),
    );

    final node = tester
        .getSemantics(find.bySemanticsLabel('Günün görevi'))
        .getSemanticsData();
    expect(node.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.byType(AppPanel));
    expect(taps, 1);

    semanticsHandle.dispose();
  });

  testWidgets('theme text keeps AA contrast on its primary surface', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final primary = AppTheme.textPrimaryColor(context);
              final secondary = AppTheme.textSubColor(context);
              final surface = AppTheme.surfaceColor(context);
              expect(_contrast(primary, surface), greaterThanOrEqualTo(4.5));
              expect(_contrast(secondary, surface), greaterThanOrEqualTo(4.5));
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
  });
}
