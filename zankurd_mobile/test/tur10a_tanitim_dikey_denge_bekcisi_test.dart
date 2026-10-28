// 9. kurul, kare 73/73b (Opus + ChatGPT): örnek soru ve açıklama kısa kalınca
// maddelerle yaş onayı arasında ~100 pt ölü boşluk kalıyordu; bütün artan yer
// tek yerde (altta) birikiyordu.
//
// Niçin sessiz kaldı: testler yalnız taşmaya ve sığmaya bakar; "çok fazla
// boş" bir taşma değildir. Artan boşluk artık üstte, kartla metin arasında ve
// altta eşit dağılır: metin bandının altı ile yaş onayı arası en çok ~48 pt.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';

import 'support/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('390x844: metin bandı ile birincil düğme arası en çok 112 pt', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();
    final text = tester.getRect(
      find.byKey(const ValueKey('onboarding-text-scrollbar')),
    );
    // 2026-10-24: yaş kutusu kalktı; metin bandının altındaki ilk öğe artık
    // birincil "Sonraki" düğmesidir.
    final next = tester.getRect(find.text('Devam'));
    expect(text.bottom, lessThanOrEqualTo(next.top));
    expect(next.top - text.bottom, lessThanOrEqualTo(48 + 64));
  });
}
