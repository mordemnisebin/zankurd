import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('açılış zemini yerel açılış ekranının düz zemini', (
    tester,
  ) async {
    // Gradyan YOK: yerel ekran düz renk; gradyan ilk satırda bile renk
    // sıçratırdı (bkz. launch_frame_gecis_test.dart).
    for (final (label, theme, expected) in [
      ('açık', AppTheme.light(), AppTheme.lightBg),
      ('koyu', AppTheme.dark(), AppTheme.bg),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(label),
          theme: theme,
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
      expect(bg.color, expected, reason: '$label tema');
    }
  });

  testWidgets('koyu temada beyaz flaş yapmadan tema zeminini kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const SplashScreen(
          next: SizedBox.shrink(),
          duration: Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();

    // Logo kendi beyaz karesini taşıdığı için Scaffold zemini artık
    // tema-duyarlı: koyu modda koyu, açık modda açık (2026-07-17 fix).
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.bg);
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
