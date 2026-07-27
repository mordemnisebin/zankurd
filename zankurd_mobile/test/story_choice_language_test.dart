import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Hikâye şıkkı her iki dilde de Kurmancîyi gösterir.
///
/// 2026-07-27: hikâye gövdesi her zaman Kurmancî cümleyi üstte, Türkçe
/// çevirisini altta gösteriyordu; şıklar ise yalnız arayüz dilini. Türkçe
/// arayüzde öğrenci Kurmancî bir cümle okuyup **Türkçe** şıklardan
/// seçiyordu — alıştırmanın Kurmancî üretim kısmı hiç yoktu.
///
/// Kusur sessizdi çünkü ekran çalışıyordu ve metinler doğruydu; yanlış
/// olan hangi dilin nerede duracağıydı. Bunu ancak ekranı öğrencinin
/// gözüyle okuyunca fark edersin, o yüzden bekçi burada.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpStory(WidgetTester tester, String lang) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        // Anahtarsız ikinci pump aynı sağlayıcıyı yeniden kullanır ve
        // ikinci dil turu sessizce birinciyi ölçer.
        key: ValueKey(lang),
        create: (_) => LanguageProvider()..setLang(lang),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: StoryScreen(story: cayxaneStory),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('şıklar iki arayüz dilinde de Kurmancî metni taşır', (
    tester,
  ) async {
    for (final lang in ['tr', 'ku']) {
      await pumpStory(tester, lang);
      expect(
        find.text('Çayekê, ji kerema xwe.'),
        findsOneWidget,
        reason: '$lang arayüzde şıkkın Kurmancîsi yok',
      );
      expect(
        find.text('Bir çay, lütfen.'),
        findsOneWidget,
        reason: '$lang arayüzde şıkkın çevirisi yok',
      );
    }
  });
}
