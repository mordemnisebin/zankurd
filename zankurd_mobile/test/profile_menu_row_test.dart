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
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

// Profil menüsü renkleri ekran kimliğiyle yarışmamalı. İkon karoları yalnız
// üç semantik role bağlı kalır.
// 2026-09-29 Şahnê: roller öğrenme (Zimrût), ödül/mağaza (Zêr) ve nötr
// (ayarlar, çıkış); eski "yıkıcı eylem=kırmızı" kalktı — Şaş bir durum
// rengidir ve çıkışın geri dönüşsüzlüğünü onay diyaloğu söyler.
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
    // 2026-09-29 Şahnê: satırlar `SahneListRow.icon`dur ve renk yalnız
    // ROL taşır (öğrenme Zimrût, mağaza Zêr, ayarlar/çıkış nötr). Ham
    // tema aksanı hiç yazılmaz; çıkış kırmızıya boyanmaz (kırmızı durum
    // rengidir, eylem rengi değil).
    expect(source, isNot(contains('iconColor: AppTheme')));
    expect(source, isNot(contains('AppTheme.')));
    expect(
      RegExp(r'role: SahneRole\.learn').allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
    expect(source, contains('role: SahneRole.gold'));
    expect(source, isNot(contains('role: SahneRole.race')));
  });

  testWidgets('profil menü satırları üç rolle sınırlıdır', (tester) async {
    await tester.pumpWidget(
      wrap(ProfileScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final shop = find.byKey(const ValueKey('profile-menu-icon-Dukan'));
    expect(shop, findsOneWidget);
    final row = tester.widget<SahneListRow>(shop);
    expect(row.role, SahneRole.gold);

    final roles = tester
        .widgetList<SahneListRow>(find.byType(SahneListRow))
        .map((r) => r.role)
        .toSet();
    expect(
      roles.difference({SahneRole.learn, SahneRole.gold, SahneRole.neutral}),
      isEmpty,
    );
  });
}
