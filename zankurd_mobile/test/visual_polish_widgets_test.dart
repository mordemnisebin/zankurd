import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
import 'package:zankurd_mobile/src/widgets/app_row_card.dart';
import 'package:zankurd_mobile/src/widgets/mode_card.dart';
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
      // Şahnê (2026-09-29): köşe yuvarlak değil kesik (45° pah); kartlar
      // iki temada da aynı L pahını taşır.
      final shape = theme.cardTheme.shape! as BeveledRectangleBorder;

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

  testWidgets(
    'identity header uses a quiet tonal surface instead of a hero gradient',
    (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: ScreenIdentityHeader(
                title: 'Kurmancî hîn bibe',
                subtitle: 'Riya xwe bi aramî û bi gavên zelal bidomîne.',
                accent: AppTheme.playGreen,
                icon: Icons.school_outlined,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byType(ScreenIdentityHeader);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: header,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        final context = tester.element(header);

        expect(decoration.gradient, isNull);
        expect(decoration.color, AppTheme.surfaceColor(context));
        expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
        expect(decoration.border, isNotNull);

        final title = tester.widget<Text>(find.text('Kurmancî hîn bibe'));
        final subtitle = tester.widget<Text>(
          find.text('Riya xwe bi aramî û bi gavên zelal bidomîne.'),
        );
        expect(title.style?.color, AppTheme.textPrimaryColor(context));
        expect(subtitle.style?.color, AppTheme.textSubColor(context));
      }
    },
  );

  testWidgets(
    'identity header lets long Kurmancî copy wrap instead of truncating it',
    (tester) async {
      const longTitle = 'Rêwitiya hînbûna Kurmancî ya rojane û pêşketina te';
      const longSubtitle =
          'Bi dersên kurt, dubarekirina jîr û gavên zelal her roj pêş bikeve.';

      await tester.binding.setSurfaceSize(const Size(320, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: ScreenIdentityHeader(
                title: longTitle,
                subtitle: longSubtitle,
                accent: AppTheme.playGreen,
                icon: Icons.school_outlined,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text(longTitle));
      final subtitle = tester.widget<Text>(find.text(longSubtitle));
      expect(title.maxLines, isNull);
      expect(title.overflow, isNull);
      expect(subtitle.maxLines, isNull);
      expect(subtitle.overflow, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared section heading keeps one quiet hierarchy and trailing action',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ScreenSectionHeading(
              title: 'Riyên hînbûnê',
              subtitle: 'Rêya ku ji bo te baştir e hilbijêre û bidomîne.',
              trailing: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heading = find.byType(ScreenSectionHeading);
      final semantics = tester.getSemantics(heading).getSemanticsData();
      expect(semantics.flagsCollection.isHeader, isTrue);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      final title = tester.widget<Text>(find.text('Riyên hînbûnê'));
      final subtitle = tester.widget<Text>(
        find.text('Rêya ku ji bo te baştir e hilbijêre û bidomîne.'),
      );
      expect(title.maxLines, isNull);
      expect(title.overflow, isNull);
      expect(subtitle.maxLines, isNull);
      expect(subtitle.overflow, isNull);

      semanticsHandle.dispose();
    },
  );

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

  testWidgets(
    'navigation cards let long Kurmancî copy breathe on narrow screens',
    (tester) async {
      const modeTitle = 'Bi hevalên xwe re pêşbaziya taybet saz bike';
      const rowTitle = 'Dersên ku ji bo pêşketina te tên pêşniyarkirin';
      const rowSubtitle =
          'Ji cihê ku rawestiyayî bidomîne û mijarên xwe dubare bike.';

      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ModeCard(
                      icon: Icons.people_outline,
                      accent: AppTheme.playGreen,
                      title: modeTitle,
                      subtitle: 'Odeyek ava bike û bi hev re bilîze.',
                      onTap: () {},
                      emphasis: ModeCardEmphasis.secondary,
                    ),
                    const SizedBox(height: 12),
                    AppRowCard(
                      icon: Icons.menu_book_outlined,
                      accent: AppTheme.playGreen,
                      title: rowTitle,
                      subtitle: rowSubtitle,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mode = tester.widget<Text>(find.text(modeTitle));
      final row = tester.widget<Text>(find.text(rowTitle));
      final supporting = tester.widget<Text>(find.text(rowSubtitle));
      expect(mode.maxLines, isNull);
      expect(mode.overflow, isNull);
      expect(row.maxLines, isNull);
      expect(row.overflow, isNull);
      expect(supporting.maxLines, isNull);
      expect(supporting.overflow, isNull);
      expect(tester.takeException(), isNull);
    },
  );

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
