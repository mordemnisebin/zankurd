import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('ana sayfa referans hiyerarşisini açık temada taşır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
          ChangeNotifierProvider(create: (_) => AuthProvider.test()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(
            repository: MockZanKurdRepository(),
            displayName: 'Zelal Test',
            scrollController: ScrollController(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('home-player-strip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-primary-play-card')),
      findsOneWidget,
    );
    expect(find.textContaining('Hoş geldin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
