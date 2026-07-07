import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_metric_tile.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testGoldens('ZankurdMetricTile accent dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const Center(
        child: ZankurdMetricTile(icon: Icons.pie_chart, value: '85%', label: 'Accuracy'),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(180, 150),
    );
    await screenMatchesGolden(tester, 'zankurd_metric_tile_accent_dark');
  });

  testGoldens('ZankurdMetricTile gold light', (tester) async {
    await tester.pumpWidgetBuilder(
      const Center(
        child: ZankurdMetricTile(
          icon: Icons.stars_rounded,
          value: '1,250',
          label: 'Points',
          color: Color(0xFFE9C46A),
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.light()),
      surfaceSize: const Size(180, 150),
    );
    await screenMatchesGolden(tester, 'zankurd_metric_tile_gold_light');
  });
}
