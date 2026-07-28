import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';

void main() {
  testWidgets('açılış zemini uygulamanın zeminiyle aynı', (tester) async {
    // 2026-07-28: bu ekran sabit koyu yeşil bir gradyan çiziyordu ve
    // açılışta üç renk arka arkaya geliyordu — sistem açılış ekranı krem
    // (#F7F4EE), sonra bu ekran koyu yeşil, sonra uygulama yine krem. İki
    // saniyede iki kez renk atlaması.
    //
    // Masaüstünde ayrıca kötü duruyordu: geniş ekranda içerik 540 pt'ye
    // sınırlanıyor ve dışı yüzey rengiyle doluyor, yani koyu panel krem
    // bir zeminin ortasında yüzen dikdörtgen gibi görünüyordu.
    //
    // Ölçüt: en alttaki dolgu, temanın kendi zemin gradyanı olmalı. Sabit
    // renge dönen bir değişiklik bu bekçiyi kırar.
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

      final decorated = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null)
          .toList();
      expect(decorated, isNotEmpty, reason: '$label temada zemin gradyanı yok');
      final colors = (decorated.first.gradient as LinearGradient).colors;
      expect(
        colors.first,
        expected,
        reason: '$label temada açılış zemini uygulamanınkinden farklı',
      );
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

    // Logo mümkün olan en büyük boyutu alır ama ekrana sığar (2026-07-24:
    // sabit 280px dar/alçak ekranda 17px taşırıyordu).
    final logo = tester.widget<AppLogo>(find.byType(AppLogo));
    expect(logo.width, lessThanOrEqualTo(280));
    expect(logo.width, greaterThan(96));
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
