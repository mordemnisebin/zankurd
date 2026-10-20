// 9. kurul, kare 109/110 (Opus + ChatGPT): "Katılım ücreti" çipleri tek
// satırda ~80 pt'e daralıyor, FittedBox yazıyı 10-11 pt'e küçültüyordu; ayrıca
// kilitli ücrete dokununca çıkan "40 jeton eksik" notu seçili "Ücretsiz" ile
// çelişkili okunuyordu (hangi ücret için eksik?).
//
// Niçin sessiz kaldı: 8. turun bekçisi çiplerin tek satırda olmasını ŞART
// koşuyordu ve yazı boyunu ölçmüyordu; eksik notu da yalnız metin olarak
// aranıyordu. Şimdi 2x2 ızgara, çip yazısı en az 14 pt (ölçeklenmeden), dört
// ücret ve alt bant 390x844'te Ayarlar açıkken birlikte görünür; dokunulan
// kilitli çip not açıkken kehribar çerçeveli "bakılan" olur ve not hangi
// ücrete ait olduğunu söyler.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_foundation.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 10;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('390x844, Ayarlar açık, 50 jeton: dört ücret ve not görünür', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: _Repo())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-room-settings-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-room-fee-50')));
    await tester.pumpAndSettle();

    final view = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-room-bottom-fade')),
        matching: find.byType(Scrollable),
      ),
    );
    final tops = <double>{};
    for (final fee in [0, 25, 50, 100]) {
      final r = tester.getRect(find.byKey(ValueKey('custom-room-fee-$fee')));
      expect(r.top, greaterThanOrEqualTo(view.top), reason: 'fee $fee');
      expect(
        r.bottom,
        lessThanOrEqualTo(view.bottom + 0.5),
        reason: 'fee $fee',
      );
      expect(r.height, greaterThanOrEqualTo(44));
      expect(r.width, greaterThan(120), reason: '2x2 geniş hücre');
      tops.add(r.top);
      // Yazı küçültülmez: FittedBox ölçeği 1, yazı >= 14 pt.
      final label = find.descendant(
        of: find.byKey(ValueKey('custom-room-fee-$fee')),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(label.first).style!.fontSize, 14);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('custom-room-fee-$fee')),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );
      // Ekrandaki (dönüşümlü) yazı yüksekliği ölçeksiz 14 pt satırdan küçük olamaz.
      expect(
        tester.getRect(label.first).height,
        greaterThanOrEqualTo(16),
        reason: 'yazı küçültülmedi',
      );
    }
    expect(tops.length, 2, reason: '2x2');
    expect(find.text('50 jeton için 40 jeton eksik'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('custom-room-shortfall')))
          .bottom,
      lessThanOrEqualTo(844),
    );
    // Bakılan çip kehribar çerçeveli, seçili (Ücretsiz) çip ayrı kalır.
    final looked = tester.widget<SahneTappable>(
      find.descendant(
        of: find.byKey(const ValueKey('custom-room-fee-50')),
        matching: find.byType(SahneTappable),
      ),
    );
    final side = (looked.shape as ShapeBorder) as OutlinedBorder;
    expect(
      side.side.color,
      SahneTokens.of(
        tester.element(find.byKey(const ValueKey('custom-room-fee-50'))),
      ).shortfallTx,
    );
    // Yetebilen çipe dokunmak notu kapatır, çerçeve söner.
    await tester.tap(find.byKey(const ValueKey('custom-room-fee-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-room-shortfall')), findsNothing);
  });
}
