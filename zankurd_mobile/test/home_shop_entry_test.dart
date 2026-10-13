// 2026-09-29 doğallık (K6): jeton çipi yalnız bakiye varken; bekçi bakiyeli depoyla.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Mağazaya giden yolun bekçisi.
///
/// 2026-07-27 denetimi: mağazaya tek giriş profil ekranının içindeydi.
/// Coin kazanan oyuncu onu nerede harcayacağını bulamıyordu — oysa ana
/// ekranın tepesinde bakiyeyi gösteren bir rozet zaten duruyor. Rozet
/// artık mağazayı açar.
///
/// 2026-09-29 doğallık (K6): bakiye sıfırken çip çizilmez ("0" bilgi değil
/// boş kalıp). Bekçi artık bakiyesi olan oyuncuda çipin mağazayı açtığını,
/// sıfır bakiyede ise çipin hiç çizilmediğini ölçer.
class _CoinRepo extends MockZanKurdRepository {
  _CoinRepo(this.coins);

  final int coins;

  @override
  Future<int> loadCoinBalance() async => coins;
}

Finder _coinGlyph() => find.byWidgetPredicate(
  (w) => w is SahneGlyph && w.kind == SahneGlyphKind.coin,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });
  });

  testWidgets('coin rozeti mağazayı açar', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: HomeScreen(repository: _CoinRepo(120))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Bakiye görünüyorsa ekran okuyucu da miktarı duyar ve çip bir düğmedir.
    final storeBadge = find.bySemanticsLabel(
      RegExp(r'^Mağaza.*120.*jeton$', caseSensitive: false),
    );
    expect(storeBadge, findsOneWidget);
    expect(
      tester
          .getSemantics(storeBadge)
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();

    // 2026-09-29 Şahnê: jeton rozeti Lucide ikonu değil Şahnê jeton glifidir
    // (`SahneGlyph` coin, stat çipinde); kural aynı: rozet mağazayı açar.
    await tester.tap(_coinGlyph());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShopScreen), findsOneWidget);
  });

  testWidgets('sıfır bakiyede jeton çipi yok', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: HomeScreen(repository: _CoinRepo(0))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_coinGlyph(), findsNothing);
  });
}
