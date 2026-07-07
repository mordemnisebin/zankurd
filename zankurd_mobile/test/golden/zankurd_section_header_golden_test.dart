import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_section_header.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testGoldens('ZankurdSectionHeader with subtitle dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const Padding(
        padding: EdgeInsets.all(16),
        child: ZankurdSectionHeader(
          title: 'Your Progress',
          subtitle: 'Weekly statistics overview',
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(360, 130),
    );
    await screenMatchesGolden(tester, 'zankurd_section_header_dark');
  });

  testGoldens('ZankurdSectionHeader with action light', (tester) async {
    await tester.pumpWidgetBuilder(
      const Padding(
        padding: EdgeInsets.all(16),
        child: ZankurdSectionHeader(
          title: 'Sections',
          subtitle: 'Manage your content',
          actionLabel: 'See All',
        ),
      ),
      wrapper: materialAppWrapper(theme: AppTheme.light()),
      surfaceSize: const Size(380, 100),
    );
    await screenMatchesGolden(tester, 'zankurd_section_header_light');
  });
}
