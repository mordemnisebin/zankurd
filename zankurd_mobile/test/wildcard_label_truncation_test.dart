import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Joker etiketleri hiçbir dilde kırpılmaz.
///
/// ## Kusur
///
/// Etiket `maxLines: 1` idi ve 390px genişlikte dört jokere bölünen barda her
/// düğmeye ~80px düşüyor. Türkçe etiketler ("Şık İpucu", "Soru Değiştir")
/// sığıyordu; Kurmancî olanlar sığmıyordu ve oyuncu "Alîkariya Be…" ile
/// "Pirsê Biguhe…" görüyordu — yani jokerin ne yaptığını okuyamıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Kusur yalnız ürünün ASIL dilinde vardı. Ekran turu quiz ekranını Türkçe ve
/// karanlık temada basıyor, Kurmancî'de hiç basmıyordu; joker barının kendi
/// önizlemesi (`tool/screenshots/wildcard_bar_preview_test.dart`) de Türkçe
/// koşuyordu. Widget testleri etiketin varlığını arıyordu, genişliğini değil
/// — `find.text('Alîkariya Bersivê')` kırpılmış bir `Text` için de bulur,
/// çünkü kırpma çizim aşamasında olur (2026-08-16 taraması).
///
/// ## Kural
///
/// Bekçi punto ya da satır sayısı gibi bir uygulama ayrıntısını değil,
/// sonucu bağlar: `RenderParagraph.didExceedMaxLines` hiçbir etikette doğru
/// olmamalı. Etiketler uzarsa ya da bar daralırsa test kırılır.
void main() {
  // Referans telefon genişliği; turun da kullandığı ölçü.
  const phoneWidth = 390.0;

  // Gerçek yazı tipi ŞART. `flutter test` pubspec'teki aileleri
  // kendiliğinden yüklemez ve bilinmeyen aileyi, her harfi kare olan ölçü
  // fontuna düşürür — orada 11pt bir harf 11px yer kaplar, Rubik'te ~6px.
  // Ölçü fontuyla koşan bir kırpma testi Türkçe "Soru Değiştir"i bile
  // kırpılmış sayar, yani hiçbir şey ölçmez. (bkz. support/realistic_device)
  setUpAll(loadAppFonts);

  Widget bar({required bool isKu}) {
    return Padding(
      // Quiz kartının yatay iç boşluğu kadar daraltır: bar ekranın tamamını
      // değil, kartın içini kaplar.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < WildcardType.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: WildcardButton(
                type: WildcardType.values[i],
                isKu: isKu,
                isEnabled: true,
                isActive: false,
                isUsed: false,
                isAnswered: false,
                cantAfford: false,
                onTap: () {},
              ),
            ),
          ],
        ],
      ),
    );
  }

  for (final (language, isKu) in [('Türkçe', false), ('Kurmancî', true)]) {
    testWidgets('$language joker etiketleri kırpılmadan sığar', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(phoneWidth * 3, 844 * 3);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: Center(
              child: IntrinsicHeight(child: bar(isKu: isKu)),
            ),
          ),
          languageProvider: isKu ? kurmanciLang() : turkishLang(),
        ),
      );
      await tester.pumpAndSettle();

      final truncated = <String>[];
      for (final type in WildcardType.values) {
        final label = type.label(isKu);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        if (paragraph.didExceedMaxLines) truncated.add(label);
      }

      expect(
        truncated,
        isEmpty,
        reason:
            '$language\'de şu joker etiketleri kırpılıyor: '
            '${truncated.join(', ')}. Oyuncu jokerin ne yaptığını okuyamaz.',
      );
    });
  }
}
