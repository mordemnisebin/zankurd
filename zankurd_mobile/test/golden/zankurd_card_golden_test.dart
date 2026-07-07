import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testGoldens('ZankurdCard surface dark', (tester) async {
    await tester.pumpWidgetBuilder(
      ZankurdCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zankurd Card', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Surface card with theme-aware shadow.', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(360, 160),
    );
    await screenMatchesGolden(tester, 'zankurd_card_surface_dark');
  });

  testGoldens('ZankurdCard surface light', (tester) async {
    await tester.pumpWidgetBuilder(
      ZankurdCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zankurd Card', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Surface card with theme-aware shadow.', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.light()),
      surfaceSize: const Size(360, 160),
    );
    await screenMatchesGolden(tester, 'zankurd_card_surface_light');
  });

  testGoldens('ZankurdCard premium dark', (tester) async {
    await tester.pumpWidgetBuilder(
      ZankurdCard(
        gradient: AppTheme.accentGradient,
        glowColor: AppTheme.accent,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.white, size: 24),
            SizedBox(height: 8),
            Text('Premium Card',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(360, 140),
    );
    await screenMatchesGolden(tester, 'zankurd_card_premium_dark');
  });
}
