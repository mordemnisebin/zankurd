import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Mağaza/Ayarlar'dan dönüldüğünde profil tazelenmiyordu.
///
/// `_openAvatarEditor` dönüşte `if (changed == true) _load();` yapıyordu;
/// Mağaza ve Ayarlar satırları aynı `push`ü yapıp sonucu HİÇ beklemiyordu
/// (`onTap: () { Navigator.push(...); }`) — kullanıcı mağazadan çerçeve
/// satın alsa ya da Ayarlar'da adını değiştirse, Profil'e dönünce eski
/// hâliyle kalmaya devam ediyordu (2026-08-14 denetimi).
class _RenamingRepository extends MockZanKurdRepository {
  String _name = 'Eski Ad';
  int nameLoadCalls = 0;

  void renameProfile(String name) => _name = name;

  @override
  Future<String> getProfileName() async {
    nameLoadCalls++;
    return _name;
  }
}

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => SoundProvider()),
    ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
    ChangeNotifierProvider(create: (_) => AnalyticsConsentProvider()),
    ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
    ChangeNotifierProvider(create: (_) => PremiumService.fallback()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Mağaza\'dan dönünce profil yeniden yüklenir', (tester) async {
    final repository = _RenamingRepository();
    await tester.pumpWidget(_wrap(ProfileScreen(repository: repository)));
    await tester.pumpAndSettle();

    final loadsBeforeNav = repository.nameLoadCalls;
    expect(loadsBeforeNav, greaterThan(0));

    await tester.ensureVisible(find.text('Mağaza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mağaza'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);

    // Mağazadayken profil "arka planda" değişti (kullanıcı bir şey satın
    // aldı gibi düşünülebilir) — dönüşte bu değişikliğin okunup okunmadığı
    // asıl soru: `getProfileName` yeniden çağrıldı mı?
    repository.renameProfile('Yeni Ad');

    Navigator.of(tester.element(find.byType(ShopScreen))).pop();
    await tester.pumpAndSettle();

    expect(
      repository.nameLoadCalls,
      greaterThan(loadsBeforeNav),
      reason: 'Mağazadan dönünce _load() tekrar çağrılmadı',
    );
    expect(find.text('Yeni Ad'), findsWidgets);
  });

  testWidgets('Ayarlar\'dan dönünce profil yeniden yüklenir', (tester) async {
    final repository = _RenamingRepository();
    await tester.pumpWidget(_wrap(ProfileScreen(repository: repository)));
    await tester.pumpAndSettle();

    final loadsBeforeNav = repository.nameLoadCalls;

    await tester.ensureVisible(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    repository.renameProfile('Ayarlardan Sonra');

    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await tester.pumpAndSettle();

    expect(repository.nameLoadCalls, greaterThan(loadsBeforeNav));
    expect(find.text('Ayarlardan Sonra'), findsWidgets);
  });
}
