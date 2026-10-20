// 7. tasarım kurulu (2026-10-20; Opus + ChatGPT + Grok): mağaza kartında ad,
// açıklama ve fiyat neredeyse aynı ağırlıkta; açıklama 4 satıra uzayıp kartı
// şişiriyor, "N jeton eksik" kilit/fiyatla sıkışık duruyordu.
//
// ## Niçin sessiz kalırdı
//
// Yazı boyutu/ağırlığı ve satır sınırı işlevsel değildir: düğme, fiyat ve
// not testleri metni arıyordu, biçimini değil. Bekçi hiyerarşiyi sabitler:
// ad 16/600, kartta açıklama yok (AZ SÖZ), fiyat 14/600, eksik
// notu 13/500; kilit ile fiyat arası 6 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 300;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ad 16/600, kartta açıklama yok, fiyat 14/600, eksik 13/500', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testShell(child: ShopScreen(repository: _Repo())));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('shop-hero-surface'));
    final name = tester.widget<Text>(
      find.descendant(of: card, matching: find.text('VIP rozeti')),
    );
    expect(name.style?.fontSize, 16);
    expect(name.style?.fontWeight, FontWeight.w600);

    // Açıklama satırı 2026-10-20'de kaldırıldı (test/az_soz_1_test.dart).
    expect(
      find.descendant(
        of: card,
        matching: find.text('Profilinde özel VIP rozeti görünsün.'),
      ),
      findsNothing,
    );

    final price = tester.widget<Text>(
      find.descendant(of: card, matching: find.text('720')),
    );
    expect(price.style?.fontSize, 14);
    expect(price.style?.fontWeight, FontWeight.w600);

    final note = tester.widget<Text>(
      find.descendant(of: card, matching: find.text('420 jeton eksik')),
    );
    expect(note.style?.fontSize, 13);
    expect(note.style?.fontWeight, FontWeight.w500);

    // Kilit ↔ jeton glifi ↔ fiyat: 6 px.
    final shortCol = find.byKey(const ValueKey('shop-short-profile_badge_vip'));
    final lock = tester.getRect(
      find.descendant(of: shortCol, matching: find.byType(Icon)).first,
    );
    final coin = tester.getRect(
      find.descendant(of: shortCol, matching: find.byType(SahneGlyph)).first,
    );
    final priceRect = tester.getRect(
      find.descendant(of: card, matching: find.text('720')),
    );
    expect(coin.left - lock.right, closeTo(6, 0.01));
    expect(priceRect.left - coin.right, closeTo(6, 0.01));
    expect(tester.takeException(), isNull);
  });
}
