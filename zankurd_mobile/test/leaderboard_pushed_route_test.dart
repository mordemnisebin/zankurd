import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/utils/app_route.dart';

import 'support/widget_test_helpers.dart';

/// Sıralama ekranı tam rota olarak açıldığında bozuluyordu (2026-08-02, A-10).
///
/// `quiz_result_screen.dart` sonuç ekranından `AppRoute.to(LeaderboardScreen(...))`
/// ile tam rota push ediyor. Ekranın kendi `Scaffold`'u yok — sekme 2 olarak
/// kullanıldığında Scaffold'u `AppShell` sağlıyor. Tam rota olarak push
/// edildiğinde ise **hiçbir Material atası kalmıyordu** ve Flutter o durumda
/// metinleri `DefaultTextStyle.fallback()` ile, sarı çift alt çizgiyle ve
/// yanlış tipografiyle çiziyordu. Bu davranış debug'a özel DEĞİLDİR; release
/// derlemede de aynıdır.
///
/// İkinci ve daha ağır kısım: geri düğmesi yoktu. Android'de sistem geri
/// tuşu kurtarıyordu (cihazda doğrulandı), ama iOS'ta `AppRoute` düz bir
/// `PageRouteBuilder` olduğu için kaydırarak-geri hareketi de yok — yani
/// ekran çıkışsız kalıyordu. Aynı kusur 2026-07-25'te paywall'da bulunmuş ve
/// orada AppBar geri düğmesiyle çözülmüştü; sıralama atlanmıştı.
///
/// Bu bekçi iki yönü de sabitler:
///   1. Rota olarak açıldığında Material atası ve geri düğmesi VAR,
///   2. Sekme olarak gömüldüğünde geri düğmesi YOK (kabuk zaten geri veriyor).
///
/// Neden `find.byType(Material)` değil de `Material.maybeOf`: Material bulmak
/// yetmez, metnin atasında olması gerekir — asıl kusur buydu.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tam rota olarak açıldığında Material atası ve geri düğmesi var', (
    tester,
  ) async {
    await tester.pumpWidget(testShell(child: const _PushLeaderboardHome()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-leaderboard')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-back')),
      findsOneWidget,
      reason:
          'push edilen sıralamada geri düğmesi yok — iOS\'ta çıkış yolu kalmaz',
    );

    // Asıl kusur: metnin ATASINDA Material yoktu.
    final textFinder = find.byType(Text);
    expect(textFinder, findsWidgets);
    final context = tester.element(textFinder.first);
    expect(
      Material.maybeOf(context),
      isNotNull,
      reason:
          'Text bir Material atası olmadan çiziliyor — DefaultTextStyle.fallback() '
          'sarı alt çizgiyle render eder (release dahil)',
    );
  });

  testWidgets('geri düğmesine basınca rota kapanır', (tester) async {
    await tester.pumpWidget(testShell(child: const _PushLeaderboardHome()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-leaderboard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leaderboard-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('leaderboard-back')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('open-leaderboard')),
      findsOneWidget,
      reason: 'geri düğmesi rotayı kapatmadı',
    );
  });

  testWidgets('sekme olarak gömüldüğünde geri düğmesi çizilmez', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-back')),
      findsNothing,
      reason:
          'gömülü kullanımda kabuk zaten geri veriyor; ikinci bir geri düğmesi '
          'kafa karıştırır',
    );
  });
}

/// Sonuç ekranının yaptığı push'un birebir aynısı.
class _PushLeaderboardHome extends StatelessWidget {
  const _PushLeaderboardHome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const ValueKey('open-leaderboard'),
        onPressed: () => Navigator.of(context).push(
          AppRoute<void>(
            page: LeaderboardScreen(repository: MockZanKurdRepository()),
          ),
        ),
        child: const Text('aç'),
      ),
    );
  }
}
