import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
import 'package:zankurd_mobile/src/widgets/app_row_card.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

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

  testWidgets('identity header is announced as a heading', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: ScreenIdentityHeader(
            title: 'Kategoriler',
            subtitle: 'Kendine uygun bir alan seç',
            accent: AppTheme.playGreen,
            icon: Icons.category_outlined,
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(ScreenIdentityHeader));
    expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(node.label, contains('Kategoriler'));

    semanticsHandle.dispose();
  });

  test('identity header keeps its white hierarchy readable', () {
    for (final color in AppTheme.identityHeaderGradient.colors) {
      expect(_contrast(Colors.white, color), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('row cards preserve a comfortable tap target and action', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppRowCard(
            icon: Icons.menu_book_outlined,
            accent: AppTheme.culturalBrandBg,
            title: 'Dersler',
            subtitle: 'Kurmancî öğren',
            semanticValue: 'İlerleme yüzde kırk',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppRowCard)).height,
      greaterThanOrEqualTo(48),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppRowCard),
        matching: find.byType(Material),
      ),
    );
    expect(material.clipBehavior, Clip.antiAlias);
    final node = tester
        .getSemantics(find.bySemanticsLabel('Dersler. Kurmancî öğren'))
        .getSemanticsData();
    expect(node.hasAction(SemanticsAction.tap), isTrue);
    expect(node.value, 'İlerleme yüzde kırk');

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
