import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';

void main() {
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

  testWidgets('logoyu büyük gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          next: Scaffold(body: Text('SONRAKI')),
          duration: Duration(milliseconds: 200),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final logo = tester.widget<AppLogo>(find.byType(AppLogo));
    expect(logo.width, 280);
    expect(find.text('SONRAKI'), findsNothing);
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
