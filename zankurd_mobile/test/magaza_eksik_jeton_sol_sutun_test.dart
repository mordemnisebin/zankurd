// 2026-10-20 TASARIM KURULU (tur 9b): mağaza "N jeton eksik" yeri.
//
// ## Kusur
//
// Kilitli ürünün "N jeton eksik" sözü sağ sütunda, fiyat hapının altına
// sıkışıyordu; 136 px'lik sütun hem fiyatı hem sözü taşıyınca kart dar ve
// kalabalık okunuyordu (3 denetçi).
//
// ## Niçin sessiz kalırdı
//
// Eski bekçiler sözün VARLIĞINI ve rengini ölçüyordu, YERİNİ değil: söz
// hangi sütunda olursa olsun geçiyorlardı. Sözleşme: söz sol metin
// sütununda, açıklamanın ALTINDA (aynı sol kenar), sağ sütunda yalnız
// kilitli fiyat; kart iç boşluğu 14; açıklama kesilmez
// (`magaza_aciklama_kesilmez_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 300;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('eksik söz açıklamanın altında, fiyat sütununda değil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testShell(child: ShopScreen(repository: _Repo())));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('shop-hero-surface'));
    final note = find.byKey(
      const ValueKey('shop-short-note-profile_badge_vip'),
    );
    final desc = find.descendant(
      of: card,
      matching: find.text('Profilinde özel VIP rozeti görünsün.'),
    );
    final price = find.byKey(const ValueKey('shop-short-profile_badge_vip'));
    expect(note, findsOneWidget);

    final n = tester.getRect(note), d = tester.getRect(desc);
    final p = tester.getRect(price);
    // Tur 10b: söz artık eylem satırının solunda (kartın iç sol kenarı),
    // açıklamanın altında; açıklamayla yan yana değil.
    expect(n.left, lessThanOrEqualTo(d.left), reason: 'metinden sola yaslı');
    expect(n.top, greaterThanOrEqualTo(d.bottom));
    expect(n.right, lessThanOrEqualTo(p.left), reason: 'sağ sütunda değil');

    final t = SahneTokens.of(tester.element(note));
    final style = tester.widget<Text>(note).style!;
    expect(style.fontSize, 13);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.color, t.shortfallTx);

    // Kart iç boşluğu 14: önizleme karosu kartın sol kenarından 14 içeridedir.
    final tile = tester.getRect(
      find.descendant(of: card, matching: find.byType(DecoratedBox)).first,
    );
    expect(tile.left - tester.getRect(card).left, closeTo(14, 1.5));
  });
}
