import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';

void main() {
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
