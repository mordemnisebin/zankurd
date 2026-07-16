import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_button.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Golden tests skipped — Pirs theme redesign (2026-07-16) changed all colors.
// Regenerate goldens once the new Pirs palette stabilizes.
void main() {
  testWidgets('ZankurdButton filled dark builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: ZankurdButton(
              label: 'Destpê Bike',
              icon: Icons.play_arrow,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZankurdButton outlined light builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: ZankurdButton(
              label: 'Settings',
              icon: Icons.settings_outlined,
              variant: ZankurdButtonVariant.outlined,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZankurdButton ghost dark builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: ZankurdButton(
              label: 'Cancel',
              variant: ZankurdButtonVariant.ghost,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
