import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/app_haptics.dart';

import 'support/widget_test_helpers.dart';

/// Ayarlar: sık sorulan sorular ve titreşim (2026-10-27).
///
/// Bekçi: SSS satırı dokununca cevabını açar; destek satırı gerçek iletişim
/// adresini (iletisim@zankurd.com) verir; titreşim anahtarı ayarı değiştirir
/// ve kalıcı kılar.
void main() {
  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: freshMockRepository())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SSS cevabı dokununca açılır; destek adresi doğru', (
    tester,
  ) async {
    await pump(tester);
    final question = find.text('Size nasıl ulaşırım?');
    await tester.scrollUntilVisible(
      question,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('iletisim@zankurd.com'), findsNothing);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('iletisim@zankurd.com'), findsOneWidget);
  });

  testWidgets('titreşim anahtarı ayarı kapatır ve kaydeder', (tester) async {
    await pump(tester);
    await AppHaptics.setEnabled(true);
    final toggle = find.byKey(const ValueKey('settings-haptics'));
    await tester.scrollUntilVisible(
      toggle,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(AppHaptics.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppHaptics.prefsKey), isFalse);
    await AppHaptics.setEnabled(true);
  });
}
