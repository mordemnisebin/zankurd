import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_button.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testGoldens('ZankurdButton filled dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const Center(
        child: ZankurdButton(label: 'Destpê Bike', icon: Icons.play_arrow),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(300, 100),
    );
    await screenMatchesGolden(tester, 'zankurd_button_filled_dark');
  });

  testGoldens('ZankurdButton outlined light', (tester) async {
    await tester.pumpWidgetBuilder(
      const Center(
        child: ZankurdButton(
          label: 'Settings',
          icon: Icons.settings_outlined,
          variant: ZankurdButtonVariant.outlined,
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.light()),
      surfaceSize: const Size(300, 100),
    );
    await screenMatchesGolden(tester, 'zankurd_button_outlined_light');
  });

  testGoldens('ZankurdButton ghost dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const Center(
        child: ZankurdButton(
          label: 'Cancel',
          variant: ZankurdButtonVariant.ghost,
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(300, 100),
    );
    await screenMatchesGolden(tester, 'zankurd_button_ghost_dark');
  });
}
