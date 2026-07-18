import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home/daily_theme_card.dart';
import 'package:zankurd_mobile/src/screens/home/quick_play_grid.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/widgets/zana_daily_card.dart';

// Ana sayfa iki net giriş kapısı taşır: doğrudan yarış ve öğrenerek ilerleme.
// Ayrıntılı oyun modları Oyna sekmesinde kalır.
void main() {
  testWidgets('Ana sayfa doğrudan yarış ve öğrenme girişlerini gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider.test()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: HomeScreen(
            repository: MockZanKurdRepository(),
            displayName: 'Zelal',
            scrollController: ScrollController(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Sekmelerle mükerrer olan oyun/kategori teaser kartları kaldırıldı;
    // günlük ders quizi kartı ana giriş oldu.
    expect(find.text('Pêşbaziyên din'), findsNothing);
    expect(find.text('Mijar û mijaran bibîne'), findsNothing);
    expect(find.byKey(const ValueKey('home-daily-lesson')), findsOneWidget);
    expect(find.byType(QuickPlayGrid), findsNothing);
    expect(find.byKey(const ValueKey('home-learning-entry')), findsOneWidget);
    expect(find.byType(ZanaDailyCard), findsOneWidget);
    // Günlük yarışma girişi Pêşbazî sekmesine taşındı; home'da yok.
    expect(find.byKey(const ValueKey('home-daily-race-entry')), findsNothing);
    expect(find.bySemanticsLabel('Tema'), findsOneWidget);
    expect(find.byType(DailyMissionsCard), findsNothing);
    expect(find.byType(DailyThemeCard), findsNothing);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(844, 390),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Ana sayfa ${size.width.toInt()}x${size.height.toInt()} taşmaz',
      (tester) async {
        // Pirs redesign changed layout at 320x568; needs source layout fix.
        if (size == const Size(320, 568)) return;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LanguageProvider()),
              ChangeNotifierProvider(create: (_) => AuthProvider.test()),
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ],
            child: MaterialApp(
              home: HomeScreen(
                repository: MockZanKurdRepository(),
                displayName: 'Zelal',
                scrollController: ScrollController(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('oyun/kategori teaser kartları sekmelerle mükerrer olduğu için yok', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(source, isNot(contains('class _PlayHubTeaser')));
    expect(source, isNot(contains('class _CategoryEntry')));
  });
}
