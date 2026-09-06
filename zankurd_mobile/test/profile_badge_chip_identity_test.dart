import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Profildeki rozet çipleri açılan rozeti değil, tanım listesinin ilk N
/// elemanını gösteriyordu.
///
/// ## Kusur
///
/// Şerit dizini doğrudan `BadgeService.badgeDefinitions.entries`e (TÜM
/// beş rozetin SABİT tanım sırasına: streak_30, questions_500,
/// questions_1000, perfect_game, speed_demon) uyguluyordu — kullanıcının
/// GERÇEKTEN açtığı `badgeUnlocked` kümesine hiç bakmıyordu. Kullanıcı
/// yalnız `speed_demon`ı açmış olsa bile (streak_30'u AÇMAMIŞ olsa bile)
/// ilk sırada duran `streak_30`ın tanımı gösteriliyordu (2026-08-14
/// denetimi).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
      ChangeNotifierProvider(create: (_) => AnalyticsConsentProvider()),
      ChangeNotifierProvider(create: (_) => PremiumService.fallback()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  testWidgets(
    'yalnız speed_demon açıkken şerit streak_30 DEĞİL speed_demon\'u gösterir',
    (tester) async {
      // `speed_demon`, `badgeDefinitions`te SON sırada; `streak_30` İLK
      // sırada. Eski (pozisyonel) kod her zaman ilk sıradaki tanımı
      // gösterirdi — bu senaryo tam da o karışıklığı ortaya çıkarır.
      await SharedPreferences.getInstance().then(
        (prefs) =>
            prefs.setStringList('zankurd.badges.unlocked', ['speed_demon']),
      );
      BadgeService.resetInstance();

      await tester.pumpWidget(
        wrap(ProfileScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Hız Canavarı'),
        findsOneWidget,
        reason: 'açılan rozet (speed_demon) şeritte görünmüyor',
      );
      expect(
        find.text('30 Gün Streak'),
        findsNothing,
        reason:
            'kullanıcı streak_30\'u hiç açmadı ama şerit onu gösteriyor — '
            'dizin pozisyonel kalmış',
      );
    },
  );
}
