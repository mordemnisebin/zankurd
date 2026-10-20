// 8. kurul birleşik tur, kare 109: "Ayarlar" açıkken "Katılım ücreti"
// ızgarasının ikinci satırı (50, 100 jeton) kaydırma alanının altında kalıyor,
// alt bantta ise "40 jeton eksik" yazıyordu: sözü edilen seçenek ekranda yoktu.
//
// Niçin sessiz kaldı: testler çiplerin varlığına bakıyordu (`ensureVisible`
// onları görünür yapar); aynı anda görünür olup olmadıklarını kimse ölçmedi.
// Dört ücret artık tek satırda; 390×844'te Ayarlar açık ve 50 jetona
// dokunulmuşken dördü de görünür alanda ve eksik notu görünür.
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
      tops.add(r.top);
    }
    expect(tops.length, 1, reason: 'tek satır');
    expect(find.text('40 jeton eksik'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('custom-room-shortfall')))
          .bottom,
      lessThanOrEqualTo(844),
    );
  });
}
