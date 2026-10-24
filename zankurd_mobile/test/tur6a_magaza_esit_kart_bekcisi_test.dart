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

    final cards = <Finder>[
      find.byKey(const ValueKey('shop-hero-surface')),
      for (final id in [
        'spin_wheel_extra',
        'avatar_frame_gold',
        'avatar_frame_neon',
      ])
        find.byKey(ValueKey('shop-item-surface-$id')),
    ];
    final widths = <double>{};
    for (final c in cards) {
      expect(c, findsOneWidget);
      widths.add(tester.getSize(c).width);
    }
    expect(widths.length, 1, reason: 'Kartlar eşit genişlikte olmalı: $widths');

    // Alınabilen üründe eylem fiil taşır, çıplak sayı değil.
    expect(find.text('Satın al · 120'), findsOneWidget);

    // Eylem/fiyat satırının sağ kenarı her kartta aynı (tur 10b: eylem artık
    // metnin altında sağa yaslı satırda; sütun değil satır).
    final rights = <double>{};
    for (final k in [
      'shop-short-profile_badge_vip',
      'shop-buy-spin_wheel_extra',
      'shop-short-avatar_frame_gold',
      'shop-short-avatar_frame_neon',
    ]) {
      final f = find.byKey(ValueKey(k));
      expect(f, findsOneWidget);
      rights.add(tester.getTopRight(f).dx.roundToDouble());
    }
    expect(rights.length, 1, reason: 'Fiyat/eylem aynı sağ kenarda: $rights');
    expect(tester.takeException(), isNull);
  });
}
