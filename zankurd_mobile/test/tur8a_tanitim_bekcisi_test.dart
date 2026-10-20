// Tasarım kurulu tur 7 (3 denetçi), tanıtım ekranı:
//
// * "Devam etmek için kutuyu işaretle" uyarısı hiçbir şeye dokunulmadan
//   ekranda duruyordu (hata gibi okunuyordu);
// * KU/TR seçici iki ayrı düğme gibiydi (biri dolu, biri çerçeveli);
// * onay satırı ile "Sonraki" arası dengesizdi.
//
// Niçin sessiz kaldı: kurul 4 uyarının baştan görünmesini BİLEREK sabitlemişti
// (pasif düğme bozuk sanılıyordu); iki karar çelişince eski bekçi yeni
// kararı bilmiyordu. Burada yeni karar (yalnız denemeden sonra) ve tek
// segment sabitlenir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  const hint = 'Devam etmek için "13 yaşından büyüğüm" kutusunu işaretle.';

  testWidgets('uyarı yalnız kutu işaretsizken "Sonraki"ye basılınca görünür', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(hint), findsNothing, reason: 'dokunmadan görünmemeli');

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing, reason: 'işaretlenince kaybolur');
  });

  testWidgets('KU/TR tek bitişik segment: ortak kenar, iki yarı yan yana', (
    tester,
  ) async {
    await pump(tester);
    final segment = find.byKey(const ValueKey('language-toggle-segment'));
    expect(segment, findsOneWidget);
    final ku = tester.getRect(
      find.byKey(const ValueKey('onboarding-language-ku')),
    );
    final tr = tester.getRect(
      find.byKey(const ValueKey('onboarding-language-tr')),
    );
    final box = tester.getRect(segment);
    // Bitişik: aralarında boşluk yok (yalnız 1 px ayraç), ikisi de kabın içinde.
    expect(tr.left - ku.right, lessThanOrEqualTo(1.0));
    expect(ku.left, greaterThanOrEqualTo(box.left));
    expect(tr.right, lessThanOrEqualTo(box.right));
    expect(ku.height, box.height);
  });
}
