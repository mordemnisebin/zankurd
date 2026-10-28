// 2026-10-28 K11 (kurul): mağazada ayrı "N jeton eksik" satırı ve "hepsi tek tam
// genişlik satır" kararı geçersiz; yetmeyen ürün yalnız nötr fiyat hapı taşır,
// çerçeve/rozet 2 sütun karodur (bkz. magaza_eksik_jeton_sol_sutun_test).
// Tasarım kurulu tur 6: Mağaza ızgarasında iki fiyat dili ve eşit olmayan
// kartlar vardı. VIP ve Neon tam genişlik yatay, "Ekstra çevirme" ve "Altın
// çerçeve" yarım genişlik dikeydi; alınabilen üründe dolu turuncu çıplak "120",
// alınamayanlarda kilit + fiyat + "N jeton eksik" duruyordu.
//
// Niçin sessiz kaldı: testler her kartın kendi içeriğini (düğme/not var mı)
// sınıyordu, kartlar ARASI hizayı değil. Bekçi: her ürün aynı genişlikte yatay
// satır, fiyat/eylem (tur 10b: altta sağa yaslı satır) her kartta aynı sağ kenarda;
// alınabilen eylem fiil içerir ("Satın al · 120").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 300;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('bütün ürün kartları aynı genişlikte; eylem sütunu hizalı', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testShell(child: ShopScreen(repository: _Repo())));
    await tester.pumpAndSettle();

    // 2026-10-28 K11: "hepsi tek tam genişlik satır" kararı geçersiz;
    // güçlendiriciler eşit genişlikte satır, çerçeve/rozet eşit genişlikte
    // karodur ve fiyat düğmeleri hep AYNI sabit boydadır.
    double width(String id) =>
        tester.getSize(find.byKey(ValueKey('shop-item-surface-$id'))).width;
    expect({width('spin_wheel_extra'), width('joker_pack_3')}.length, 1);
    expect(
      {
        width('avatar_frame_gold'),
        width('avatar_frame_neon'),
        width('profile_badge_vip'),
      }.length,
      1,
    );

    final sizes = <Size>{};
    for (final k in [
      'shop-buy-streak_freeze',
      'shop-buy-joker_pack_3',
      'shop-buy-spin_wheel_extra',
    ]) {
      final f = find.byKey(ValueKey(k));
      if (f.evaluate().isEmpty) continue;
      sizes.add(tester.getSize(f));
    }
    // Satır düğmeleri (genişlik sabit 112) aynı boyda.
    expect(sizes.map((e) => e.width).toSet().length, 1, reason: '$sizes');
    expect(sizes.map((e) => e.height).toSet().length, 1, reason: '$sizes');

    // Satırlarda eylem sağ kenarda hizalı.
    final rights = <double>{};
    for (final k in ['shop-buy-joker_pack_3', 'shop-buy-spin_wheel_extra']) {
      final f = find.byKey(ValueKey(k));
      if (f.evaluate().isEmpty) continue;
      rights.add(tester.getTopRight(f).dx.roundToDouble());
    }
    expect(rights.length, 1, reason: 'Fiyat/eylem aynı sağ kenarda: $rights');
    expect(tester.takeException(), isNull);
  });
}
