import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('açılış zemini yerel açılış ekranının düz zemini (platform)', (
    tester,
  ) async {
    // Gradyan YOK: yerel ekran düz renk. Zemin uygulama temasını DEĞİL
    // platform parlaklığını izler (bkz. acilis_platform_parlaklik_test.dart).
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    for (final (label, brightness, expected) in [
      ('açık', Brightness.light, AppTheme.lightBg),
      ('koyu', Brightness.dark, AppTheme.bg),
    ]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(label),
          theme: AppTheme.light(),
          home: const SplashScreen(
            next: SizedBox.shrink(),
            duration: Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      final bg = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('launch-frame-bg')),
      );
      expect(bg.color, expected, reason: '$label platform');
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, expected, reason: '$label platform');
    }
  });

  testWidgets('süre dolunca sonraki ekrana geçer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          next: Scaffold(body: Text('SONRAKI')),
          duration: Duration(milliseconds: 200),
        ),
      ),
    );
    // Zamanlayıcı + geçiş animasyonu tamamlanana kadar bekle.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('SONRAKI'), findsOneWidget);
  });
}
