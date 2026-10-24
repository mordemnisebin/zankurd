// 2026-10-20 TASARIM KURULU (tur 9b): sonuçta büyük puan ile alt satır.
//
// ## Kusur
//
// "240" (64 punto) ile altındaki "puan · %67 doğruluk" arası yalnız 8 idi;
// iki denetçi (Gemini, Grok) satırın rakama yapıştığını söyledi.
//
// ## Niçin sessiz kalırdı
//
// Aralık tek `SizedBox` sabitidir; derleme ya da taşma hatası vermez, ritim
// bekçisi (`sonuc_ritim_test.dart`) yalnız amblem/kart mesafesini ölçer.
// Bu dosya puan→alt satır mesafesinin en az 16 olduğunu ve alt satırın
// ikincil metin renginde kaldığını ölçer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  heroCaptionContrast();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('puan → alt satır en az 16, alt satır okunur ikincil renkte', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: SahneResultScaffold(
          hero: const SahneResultHero(
            emblem: SizedBox(height: 44),
            title: 'Bitti',
            value: 240,
            valueKey: ValueKey('puan'),
            caption: 'puan · %67 doğruluk',
          ),
          primary: SahneResultAction(label: 'Tamam', onPressed: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final value = tester.getRect(find.byKey(const ValueKey('puan')));
    final captionFinder = find.text('puan · %67 doğruluk');
    final caption = tester.getRect(captionFinder);
    expect(caption.top - value.bottom, greaterThanOrEqualTo(16));

    final style = tester.widget<Text>(captionFinder).style!;
    final t = SahneTokens.of(tester.element(captionFinder));
    expect(style.color, isNot(t.gold));
    expect(style.color, t.heroCaptionTx);
    expect(style.fontWeight, FontWeight.w500);
  });
}

// Tur 10b kusuru: koyu temada "puan · %67 doğruluk" satırı ikincil metin
// 400 ağırlıkla 64 punto sayının altında sönük kalıyordu; sessizdi çünkü
// renk AA'yı geçiyordu, yalnız hiyerarşi zayıftı. Bekçi: iki temada da
// ≥ 4.5:1 ve ana ikincil metinden (tx2) belirgin biçimde ayrışır.
double _lum(Color c) => c.computeLuminance();
double _ratio(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void heroCaptionContrast() {
  test('sonuç alt satırı iki temada ≥ 4.5:1 ve tx2\'den ayrışır', () {
    for (final t in [SahneTokens.night, SahneTokens.day]) {
      expect(_ratio(t.heroCaptionTx, t.bg), greaterThanOrEqualTo(4.5));
      expect(_ratio(t.heroCaptionTx, t.s1), greaterThanOrEqualTo(4.5));
      expect(t.heroCaptionTx, isNot(t.tx2));
    }
  });
}
