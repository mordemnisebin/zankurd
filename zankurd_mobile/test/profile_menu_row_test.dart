import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Profil menüsü renkleri ekran kimliğiyle yarışmamalı. İkon karoları yalnız
// üç semantik role bağlı kalır: öğrenme/hesap=yeşil, prestij/mağaza=altın,
// yıkıcı eylem=kırmızı.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  test('profil menüsü rol dışı gökkuşağı aksanları kullanmaz', () {
    final source = File(
      'lib/src/screens/profile_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('iconColor: AppTheme.playCyan')));
    expect(source, isNot(contains('iconColor: AppTheme.primaryGradientStart')));
    expect(source, isNot(contains('iconColor: AppTheme.secondaryAccent')));
    expect(source, isNot(contains('iconColor: AppTheme.correct')));
    expect(
      RegExp(r'iconColor: AppTheme\.playGreen').allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
    expect(source, contains('iconColor: AppTheme.gold'));
    expect(source, contains('iconColor: AppTheme.wrong'));
  });

  testWidgets('profil menü ikonları üç anlamlı renk rolüyle sınırlıdır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ProfileScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final menuBadges = find.byKey(const ValueKey('profile-menu-icon-Dukan'));
    expect(menuBadges, findsOneWidget);

    final badge = tester.widget<Container>(menuBadges);
    final decoration = badge.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, isNotNull);
    expect(decoration.color, isNot(Colors.transparent));

    final source = File(
      'lib/src/screens/profile_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('iconColor: AppTheme.playCyan')));
    expect(source, isNot(contains('iconColor: AppTheme.secondaryAccent')));
    expect(source, contains('iconColor: AppTheme.playGreen'));
    expect(source, contains('iconColor: AppTheme.gold'));
    expect(source, contains('iconColor: AppTheme.wrong'));
  });
}
