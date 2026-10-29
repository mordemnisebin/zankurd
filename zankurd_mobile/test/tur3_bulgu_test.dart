import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/quiz_top_bar.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Simülatör turu 3 (2026-10-30) bulgularının bekçileri.
///
/// ## Engelleyici — canlı düelloda soru gelince ~7 pt kayma
///
/// iPhone 17 Pro'da (402 pt) künye "Soru 1/10 · Bilim" ilk karede iki satır,
/// bir saniye sonra tek satırdı; soru ve şıklar 21 px yukarı kaydı. Kök: üst
/// çubuğun orta yuvası iki yandaki öğelerin GERÇEK genişliğine göre
/// ölçülüyordu. Sayaç kapsülü "12"den "9"a inince daralıyor, orta yuva
/// genişliyor, künye satır sayısı değişiyordu; skor 1.000'i geçince konu
/// işaretinin düşmesi de aynı şeyi yapıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Kayma bekçileri soru ekranlarını `enableTimer: false` ile ölçüyordu:
/// sayaç hiç akmıyor, saniye hep aynı genişlikte kalıyordu. Burada GERÇEK
/// sayaç kapsülü, bütün saniye değerlerinde, dört telefon genişliğinde ve
/// iki dilde, en uzun konu adlarıyla çizilir; künyenin satır sayısı ve
/// gövdenin üst kenarı sabit kalmalıdır.
void main() {
  setUpAll(loadAppFonts);

  const categories = [
    'Teknolojî',
    'Paradigma',
    'Edebiyat',
    'Cografya',
    'Siyaset',
    'Tevlihev',
    'Ziman',
  ];
  const widths = [375.0, 390.0, 402.0, 430.0];

  Future<({double lines, double bodyTop})> measure(
    WidgetTester tester, {
    required double width,
    required String category,
    required int seconds,
    required bool ku,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        languageProvider: ku ? kurmanciLang() : null,
        child: SahneStageScaffold(
          onClose: () {},
          body: const SizedBox(key: ValueKey('tur3-body'), height: 10),
          center: QuizStageCenter(
            category: category,
            index: 8,
            total: 10,
            modeLabel: 'Düello',
          ),
          score: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 48, height: 48),
              SahneStageTimer(secondsLeft: seconds, semanticLabel: '$seconds'),
              const SizedBox(width: 48, height: 48),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('quiz-stage-kicker')),
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'künye kesilmez');
    return (
      lines: tester
          .getSize(find.byKey(const ValueKey('quiz-stage-kicker')))
          .height,
      bodyTop: tester.getTopLeft(find.byKey(const ValueKey('tur3-body'))).dy,
    );
  }

  testWidgets('sayaç kapsülü 0–99 arasında hep aynı genişlikte', (
    tester,
  ) async {
    double? width;
    for (final s in [99, 15, 12, 10, 9, 5, 3, 1, 0]) {
      await tester.pumpWidget(
        testShell(
          child: Center(
            child: SahneStageTimer(secondsLeft: s, semanticLabel: '$s'),
          ),
        ),
      );
      final w = tester.getSize(find.byType(SahneStageTimer)).width;
      width ??= w;
      expect(w, moreOrLessEquals(width, epsilon: 0.5), reason: '$s sn');
    }
  });

  for (final ku in [false, true]) {
    for (final width in widths) {
      testWidgets(
        'künye ve gövde sayaç akarken sabit — ${ku ? 'KU' : 'TR'} $width',
        (tester) async {
          for (final category in categories) {
            double? lines;
            double? top;
            for (final s in [15, 12, 10, 9, 5, 0]) {
              final m = await measure(
                tester,
                width: width,
                category: category,
                seconds: s,
                ku: ku,
              );
              lines ??= m.lines;
              top ??= m.bodyTop;
              expect(
                m.lines,
                moreOrLessEquals(lines, epsilon: 0.5),
                reason: '$category $s sn: künye boyu',
              );
              expect(
                m.bodyTop,
                moreOrLessEquals(top, epsilon: 0.5),
                reason: '$category $s sn: gövde kaydı',
              );
            }
          }
        },
      );
    }
  }
}
