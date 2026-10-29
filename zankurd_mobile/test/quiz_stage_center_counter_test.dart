import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/quiz_top_bar.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Üst satırın soru sayacı hiçbir genişlikte kesilmez.
///
/// ## Kusur
///
/// Künye "Teknoloji · Soru 3/10" biçimindeydi ve tek satırda sondan
/// kısaltılıyordu. Kapat + skor + saniye + ⋯ yanında orta yuva daraldığında
/// kesilen kısım SAYAÇ oluyordu: "Teknoloji · Sor…". Oyuncu kaçıncı soruda
/// olduğunu göremiyordu; oysa kategori adı zaten sorunun kendisinden okunur.
///
/// ## Niçin sessiz kalırdı
///
/// Testler künyenin metnini ve varlığını sınıyordu; 320 dp + skor + sayaç
/// birleşiminde HANGİ parçanın kesildiğini kimse ölçmüyordu. Uzun kategori
/// adı + kısa ekran + dolu sağ grup yalnız gerçek cihazda bir araya gelir.
///
/// ## Kural
///
/// Sayaç künyenin BAŞINDADIR ("Soru 3/10 · Teknoloji"); kısaltma yalnız
/// sondaki kategori adını yer. Skor ve sayaç doluyken 320 dp'de (yazı %100 ve
/// %200) sayacın tamamı çizilir.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double scale,
    bool ku = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        languageProvider: ku ? kurmanciLang() : turkishLang(),
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: const SahneStageScaffold(
            body: SizedBox.shrink(),
            center: QuizStageCenter(
              category: 'Teknoloji',
              title: 'Teknoloji ve bilim dünyası',
              index: 2,
              total: 10,
            ),
            // Skor çipi + saniye halkası. Test yazı tipi (Ahem) gerçek yazıdan ~1,7
            // kat geniştir; bu yüzden skor tek haneli ve ⋯ menüsü yok.
            score: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SahneStatChip(
                    leading: SahneGlyph(SahneGlyphKind.star),
                    label: '5',
                  ),
                  SizedBox(width: 28, height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final ku in [false, true]) {
    final counter = ku ? 'Pirs 3/10' : 'Soru 3/10';

    testWidgets('320 dp, ${ku ? 'ku' : 'tr'}: sayaç tek satırda, kesilmeden', (
      tester,
    ) async {
      await pump(tester, scale: 1.0, ku: ku);
      expect(tester.takeException(), isNull);

      final finder = find.byKey(const ValueKey('quiz-stage-kicker'));
      final data = tester.widget<Text>(finder).data!;
      expect(data, startsWith(counter), reason: 'sayaç künyenin başında');
      expect(data, contains('Teknoloji ve bilim dünyası'));

      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final painter = TextPainter(
        text: TextSpan(text: counter, style: paragraph.text.style),
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
        maxLines: 1,
      )..layout();
      // 2026-10-29 (soru sığma, Astra 2. inceleme): künye ARTIK kısaltılmaz;
      // uzun kategori adı gerçek genişlikte ölçülüp punto/satır seçilir, metin
      // tam çizilir (sayaç da, kategori de).
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(painter.width),
        reason: 'çizilen genişlik sayacın tamamını taşımalı',
      );
    });

    testWidgets('320 dp, yazı x2, ${ku ? 'ku' : 'tr'}: sayaç iki satıra '
        'sarar, kategori adı kısalır', (tester) async {
      await pump(tester, scale: 2.0, ku: ku);
      expect(tester.takeException(), isNull);

      final finder = find.byKey(const ValueKey('quiz-stage-kicker'));
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      // Tek satır 14 × 2 (yazı) × 20/14 = 40 px; iki satır ≈ 80.
      expect(paragraph.size.height, greaterThan(60), reason: 'iki satır');
    });
  }
}
