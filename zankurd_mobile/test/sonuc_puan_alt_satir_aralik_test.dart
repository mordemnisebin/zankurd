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
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('puan → alt satır en az 16, alt satır ikincil renkte', (
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
    expect(style.color, t.tx2);
  });
}
