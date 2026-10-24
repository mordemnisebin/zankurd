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

  testWidgets('yaş kutusu yok: "Sonraki" ilk dokunuşta ilerler, uyarı çıkmaz', (
    tester,
  ) async {
    await pump(tester);
    // 2026-10-24: yaş onayı kalktı (kutu "Sonraki"yi kilitliyor, ilk ekranda
    // kırmızı hata gösteriyordu). Hiçbir aşamada uyarı metni olmamalı.
    expect(find.textContaining('13 yaş'), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-age-gate')), findsNothing);

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(find.text('Başla'), findsOneWidget, reason: 'ikinci sayfaya geçti');
    expect(find.textContaining('13 yaş'), findsNothing);
  });

  testWidgets('dil seçici: tek bitişik segment, Kurmancî solda Türkçe sağda', (
    tester,
  ) async {
    await pump(tester);
    final picker = find.byKey(const ValueKey('language-picker'));
    expect(picker, findsOneWidget);
    final ku = tester.getRect(
      find.byKey(const ValueKey('onboarding-language-ku')),
    );
    final tr = tester.getRect(
      find.byKey(const ValueKey('onboarding-language-tr')),
    );
    final box = tester.getRect(picker);
    // Bitişik: aralarında boşluk yok (yalnız 1 px ayraç), ikisi de kabın içinde.
    expect(ku.left, lessThan(tr.left), reason: 'Kurmancî ÖNCE');
    expect(tr.left - ku.right, lessThanOrEqualTo(1.0));
    expect(ku.left, greaterThanOrEqualTo(box.left));
    expect(tr.right, lessThanOrEqualTo(box.right));
    expect(ku.height, greaterThanOrEqualTo(56));
  });
}
