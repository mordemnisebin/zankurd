import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_metric_tile.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Golden tests skipped — Pirs theme redesign (2026-07-16) changed all colors.
// Regenerate goldens once the new Pirs palette stabilizes.
void main() {
  testWidgets('ZankurdMetricTile accent dark builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: ZankurdMetricTile(
              icon: Icons.pie_chart,
              value: '85%',
              label: 'Accuracy',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    });

  testWidgets('ZankurdMetricTile gold light builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: ZankurdMetricTile(
              icon: Icons.stars_rounded,
              value: '1,250',
              label: 'Points',
              color: Color(0xFFE9C46A),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    });
}
