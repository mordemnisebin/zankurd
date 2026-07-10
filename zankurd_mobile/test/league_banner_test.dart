import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('haftalık görünümde lig bandı görünür', (tester) async {
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Varsayılan sekme haftalıktır; mock listede oturum sahibi yoksa
    // oyuncu Bronz Lig'den başlar ve davet metni görünür.
    await tester.pumpWidget(
      _shell(LeaderboardScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('league-banner')), findsOneWidget);
    expect(find.text('Bronz Lig'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
