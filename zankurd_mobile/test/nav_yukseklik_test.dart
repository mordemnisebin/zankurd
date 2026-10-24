import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/providers/bilingual_labels_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'support/widget_test_helpers.dart';

/// Alt sekme çubuğu çentikli iPhone'da 62 pt şişiyordu (2026-10-22).
///
/// ## Kusur
///
/// İki dilli etiketler açıkken alt çubuk `SafeArea(top: false)` içinde
/// çiziliyordu; `NavigationBar` üst güvenli alanı (durum çubuğu, ~62 pt)
/// kendi içinde bir kez daha karşılıyordu. Çubuk 60 yerine 122 pt oldu:
/// her sekmede içerik, ikonların üstündeki boş bir bantta kesiliyordu.
///
/// ## Niçin sessiz kalabilirdi
///
/// Testler ve ekran turu güvenli alansız yüzeyde koşar; orada üst dolgu
/// 0'dır ve çubuk doğru boyda görünür. Yalnız gerçek iPhone'da çıkar.
///
/// ## Bekçi
///
/// iPhone 17 Pro güvenli alanıyla (üst 62, alt 34) çubuk, etiket satırı
/// açıkken 60 + 12 + 34, kapalıyken 64 + 34 yüksekliğindedir.
void main() {
  setUp(() {
    AchievementStore.resetInstance();
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

  for (final (bilingual, expected) in [(true, 60.0 + 12 + 34), (false, 98.0)]) {
    testWidgets('çentikli iPhone: iki dilli=$bilingual çubuk $expected pt', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => BilingualLabelsProvider(initialEnabled: bilingual),
            ),
          ],
          child: testShell(
            languageProvider: kurmanciLang(),
            child: AppShell(repository: freshMockRepository()),
          ),
        ),
      );
      // Kabukta sürekli dönen bir yükleyici var; sayılı pump.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final nav = tester.getRect(find.byWidget(scaffold.bottomNavigationBar!));
      expect(nav.height, expected);
      expect(nav.bottom, 874);
    });
  }
}
