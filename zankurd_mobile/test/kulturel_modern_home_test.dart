import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home/daily_theme_card.dart';
import 'package:zankurd_mobile/src/screens/home/hero_card.dart';
import 'package:zankurd_mobile/src/screens/home/quick_play_grid.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/widgets/zana_daily_card.dart';

// Sereke ve Bilîze aynı 4 modu birebir tekrarlıyordu (bkz. tasarım
// değerlendirmesi 2026-07-13). QuickPlayGrid artık yalnızca Bilîze'de;
// Sereke oraya yönlendiren tek bir teaser gösterir (home-play-hub-teaser).
void main() {
  testWidgets('Sereke tek CTA, Bilîze teaserı ve tek Zana çağrısı gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.byType(HeroCard), findsOneWidget);
    expect(find.byType(QuickPlayGrid), findsNothing);
    expect(find.byKey(const ValueKey('home-play-hub-teaser')), findsOneWidget);
    expect(find.byType(ZanaDailyCard), findsOneWidget);
    expect(find.byType(DailyMissionsCard), findsNothing);
    expect(find.byType(DailyThemeCard), findsNothing);
  });
}
