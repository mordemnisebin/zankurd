// Tur 7 kare 109/110: "Özel oda oluştur" sayfasında başlığın altında yarım
// kesik çip satırı ve "Katılım ücreti" ızgarasının alt satırı ayraçla kesik
// duruyordu.
//
// Niçin sessiz kaldı: testler çiplerin VARLIĞINA ve konumuna bakıyordu; bir
// satırın yarısının kaydırma kenarında kesilmesi yalnız ekran görüntüsünde
// görünür. Burada 390×844'te (dpr 1) kapalı sayfanın kaydırmasız sığdığı,
// Ayarlar açılınca içeriğin sona kaydığı ve en alt satırın (50/100 jeton)
// kesilmeden görünür alanın içinde kaldığı ölçülür.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 10;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ScrollPosition> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: _Repo())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('custom-room-bottom-fade')),
      matching: find.byType(Scrollable),
    );
    return tester.state<ScrollableState>(scrollable).position;
  }

  Rect viewportRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byKey(const ValueKey('custom-room-bottom-fade')),
      matching: find.byType(Scrollable),
    ),
  );

  testWidgets('kapalı sayfa 390×844 telefonda kaydırmadan sığar', (
    tester,
  ) async {
    final position = await open(tester);
    expect(position.maxScrollExtent, 0, reason: 'kesik satır doğmamalı');
    final chip = tester.getSize(
      find.byKey(const ValueKey('custom-room-cat-mixed')),
    );
    expect(chip.height, greaterThanOrEqualTo(44));
  });

  testWidgets(
    'Ayarlar açılınca içerik sona kayar; son ücret satırı kesilmez, boşluk yok',
    (tester) async {
      final position = await open(tester);
      final row = find.byKey(const ValueKey('custom-room-settings-row'));
      await tester.tap(row);
      await tester.pumpAndSettle();

      // Yetmeyen ücrete dokun: not belirir, ızgara yine kesilmeden görünür.
      await tester.tap(find.byKey(const ValueKey('custom-room-fee-100')));
      await tester.pumpAndSettle();
      final after = viewportRect(tester);
      for (final fee in [50, 100]) {
        final r = tester.getRect(find.byKey(ValueKey('custom-room-fee-$fee')));
        expect(r.bottom, lessThanOrEqualTo(after.bottom + 0.5));
        expect(r.top, greaterThanOrEqualTo(after.top));
      }
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    },
  );
}
