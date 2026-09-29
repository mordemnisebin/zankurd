import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Joker adları hiçbir dilde kırpılmaz.
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
/// Kusur yalnız ürünün ASIL dilinde vardı ve tur quiz ekranını Kurmancî'de
/// hiç basmıyordu (2026-08-16 taraması).
///
/// ## 2026-09-29 Şahnê
///
/// Şahnê jokeri adını ekranda YAZMAZ (ikon + jeton + fiyat; maketteki
/// `.sh-jk`): ad ekran okuyucuya Semantics'te, görene uzun basışta ipucu
/// olarak gider. Kırpılacak görünür etiket kalmadı; bekçi aynı sonucu yeni
/// yerinde bağlar: adın TAMAMI Semantics'te ve ipucunda durur, dar barda ve
/// %200 yazıda düğme taşmaz.
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
    for (final (width, scale) in [(phoneWidth, 1.0), (320.0, 2.0)]) {
      testWidgets(
        '$language joker adları ${width.toInt()}px %${(scale * 100).toInt()} '
        'yazıda bütün kalır',
        (tester) async {
          final handle = tester.ensureSemantics();
          tester.view.devicePixelRatio = 3.0;
          tester.view.physicalSize = Size(width * 3, 844 * 3);
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            testShell(
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Center(
                      child: IntrinsicHeight(child: bar(isKu: isKu)),
                    ),
                  ),
                ),
              ),
              languageProvider: isKu ? kurmanciLang() : turkishLang(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'joker barı taştı');

          for (final type in WildcardType.values) {
            final label = type.label(isKu);
            final button = find.byWidgetPredicate(
              (w) => w is WildcardButton && w.type == type,
            );
            final semantics = tester.getSemantics(button).getSemanticsData();
            expect(
              semantics.label,
              contains(label),
              reason: '$label ekran okuyucuya bütün olarak gitmeli.',
            );
            expect(
              find.byTooltip(label),
              findsOneWidget,
              reason: '$label uzun basışta ipucu olarak görünmeli.',
            );
          }
          handle.dispose();
        },
      );
    }
  }
}
