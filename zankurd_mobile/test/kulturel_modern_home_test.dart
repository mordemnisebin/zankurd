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

void main() {
  testWidgets('Sereke tek CTA hızlı oyunlar ve tek Zana çağrısı gösterir', (
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
    expect(find.byType(QuickPlayGrid), findsOneWidget);
    expect(find.byType(ZanaDailyCard), findsOneWidget);
    expect(find.byType(DailyMissionsCard), findsNothing);
    expect(find.byType(DailyThemeCard), findsNothing);
  });
}
