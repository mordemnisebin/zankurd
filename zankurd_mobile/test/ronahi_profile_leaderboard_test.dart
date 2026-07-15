import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _baseShell(Widget child, {bool profile = false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      if (profile) ...[
        ChangeNotifierProvider(create: (_) => AuthProvider.test()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
        ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
      ],
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('liderlik referansın kompakt liste sözleşmesini taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      _baseShell(LeaderboardScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-compact-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('leaderboard-rank-row-4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profil açık kimlik kartını taşır', (tester) async {
    await tester.pumpWidget(
      _baseShell(
        ProfileScreen(repository: MockZanKurdRepository()),
        profile: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-identity-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-avatar-edit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
