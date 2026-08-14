import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
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

/// Profil "Yanlışlarım" satırı açılamayacak soruları sayıyordu.
///
/// ## Kusur
///
/// `MistakeStore.count`/`readyCount` yalnız kayıtlı kimlik sayısını
/// verir, kaynağa bakmaz. Çevrimiçi maçlarda yanlış yapılan sorular
/// sunucu UUID'siyle kaydedilir (`get_room_questions` satırın `id`sini
/// döndürür) ve içerik kalite karantinasıyla bankadan çıkarılan sorular
/// da aynı şekilde asla çözülemez. Profil satırı bu ham sayıyı
/// gösteriyor, dokunulunca `_startMistakePractice` gerçek kesişimi boş
/// bulup "hepsi bekliyor" gibi yanlış bir mesaj gösteriyordu — oysa
/// gerçek neden o sorunun artık hiçbir yerde bulunamamasıydı (2026-08-14
/// denetimi; `todays_review_card.dart`taki 2026-08-06 düzeltmesiyle aynı
/// kök neden).
void main() {
  setUp(() {
    MistakeStore.resetInstance();
  });

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
    child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );

  testWidgets(
    'çözülemeyen UUID kayıtları "Yanlışlarım" toplamını şişirmez',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': [
          'offline_0005',
          // Çevrimiçi maçtan gelen, paketli bankada karşılığı olmayan id.
          '9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44',
          'c3a0f5b1-2d64-4e89-b7f3-6a8e2c9d1077',
        ],
      });

      await tester.pumpWidget(
        wrap(ProfileScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Toplam: 3'),
        findsNothing,
        reason:
            'Satır açılamayacak soruları sayarsa kullanıcıya olmayan bir '
            'iş vaat eder',
      );
      expect(find.textContaining('Toplam: 1'), findsOneWidget);
    },
  );

  testWidgets(
    'yalnız çözülemeyen UUID varsa satır "hiç yanlışın yok" gösterir ve '
    'dokununca doğru mesajı verir',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': ['9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44'],
      });

      await tester.pumpWidget(
        wrap(ProfileScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      // Açılamayan tek kayıt sayılmadığı için satır 0'a düşer ve "hiç
      // yanlışın yok" durumunu gösterir — "Tekrar Edilecek/Toplam"
      // biçimi yalnız gerçekten launchable bir kayıt varken görünür.
      expect(
        find.text('Hiç yanlışın yok — aferin!'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Yanlışlarım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yanlışlarım'));
      await tester.pumpAndSettle();

      // Toplam zaten 0 göründüğü için doğru mesaj "önce oyna"dır, yanlış
      // olan "hepsi bekliyor" değil.
      expect(
        find.text('Tekrar edilecek yanlış yok. Önce bir yarış oyna!'),
        findsOneWidget,
      );
    },
  );
}
