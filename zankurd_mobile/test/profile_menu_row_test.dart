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
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Pirs-tarzı: menü satırlarındaki ikonlar renkli, yuvarlak rozet arka
// planı taşır (Ayarlar ve Mağaza'daki desenle tutarlı) — önceden çıplak
// Icon() idi.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
      ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('menü satırı ikonu renkli daire rozet arka planı taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ProfileScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<Container>(
      find.byKey(const ValueKey('profile-menu-icon-Dukan')),
    );
    final decoration = badge.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, isNotNull);
    expect(decoration.color, isNot(Colors.transparent));
  });
}
