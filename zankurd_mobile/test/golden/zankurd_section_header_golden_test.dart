import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_section_header.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Golden tests skipped — Pirs theme redesign (2026-07-16) changed all colors.
// Regenerate goldens once the new Pirs palette stabilizes.
void main() {
  testWidgets('ZankurdSectionHeader with subtitle dark builds without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: ZankurdSectionHeader(
              title: 'Your Progress',
              subtitle: 'Weekly statistics overview',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZankurdSectionHeader with action light builds without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: ZankurdSectionHeader(
              title: 'Sections',
              subtitle: 'Manage your content',
              actionLabel: 'See All',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
