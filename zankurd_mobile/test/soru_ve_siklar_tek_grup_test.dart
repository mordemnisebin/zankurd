// 2026-10-20 TASARIM KURULU (tur 6b): soru ile şıklar tek dikey grup.
//
// ## Kusur
//
// Soru ekranında şıklar alta (başparmak bölgesi) oturuyordu ama soru metni
// `spaceBetween` yüzünden boş alanın ortasında yüzüyordu: soru ile ilk şık
// arasında ~150 pt, şıklarla alt çubuk arasında da boşluk vardı; soru metni
// (24/30) şıklara göre cılız kalıyordu. Dört denetçi aynı şeyi söyledi.
//
// ## Niçin sessiz kalırdı
//
// Boşluk bir derleme ya da taşma hatası değildir; her test soru ve şıkların
// "var" olduğunu görür. Yalnız aralarındaki mesafe ölçülürse yakalanır.
//
// Sözleşme: soru metni ilk şıkkın hemen üstünde (24-40 pt), artan boşluk
// grubun ÜSTÜNDE; soru 26/32; 320 px ve %200 yazıda taşma yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
  });

  Future<void> pump(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: testShell(
          child: QuizScreen(
            repository: repo,
            room: repo.createRoom(),
            questions: repo.questions.take(2).toList(),
            enableTimer: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('soru kartı şıkların hemen üstünde, soru ÜSTTEN başlar', (
    tester,
  ) async {
    await pump(tester, const Size(390, 844), 1.0);
    final card = tester.getRect(find.byKey(const ValueKey('quiz-prompt-card')));
    final area = tester.getRect(
      find.byKey(const ValueKey('quiz-answer-content')),
    );
    final gap = _gapToNextBlock(tester, card, area);
    // K6 (2026-10-28) GEÇERSİZ KILDI: eski 24-40 aralığı ve "boşluk grubun
    // üstünde" (anchorHeight) kararı. Yeni sözleşme: soru kartı alanın
    // tepesinde, kart ile ilk şık arası 16.
    expect(gap, inInclusiveRange(12, 24), reason: 'soru-şık arası $gap');
    expect(card.top - area.top, lessThan(8));
    expect(SahneType.question.fontSize, 26);
  });

  for (final c in [(const Size(320, 640), 1.0), (const Size(390, 844), 2.0)]) {
    testWidgets('${c.$1.width.toInt()}px @${c.$2}: taşma yok', (tester) async {
      await pump(tester, c.$1, c.$2);
      expect(tester.takeException(), isNull);
    });
  }
}

/// [prompt]'un altından başlayıp [area]'nın içindeki ilk şık satırına kadar
/// olan boşluk: prompt altı ile alandaki ilk dokunulur çubuk üstü arası.
double _gapToNextBlock(WidgetTester tester, Rect prompt, Rect area) {
  final bars = find.descendant(
    of: find.byKey(const ValueKey('quiz-answer-content')),
    matching: find.byType(InkWell),
  );
  var top = double.infinity;
  for (final e in bars.evaluate()) {
    final r = tester.getRect(find.byElementPredicate((x) => x == e));
    if (r.top >= prompt.bottom - 1 && r.top < top) top = r.top;
  }
  return top - prompt.bottom;
}
