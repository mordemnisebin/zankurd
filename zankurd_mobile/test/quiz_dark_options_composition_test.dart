import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Soru ekranı kompozisyonu ve koyu tema şıkları (7. tasarım kurulu, 5
/// denetçinin 5'i).
///
/// ## Kusurlar
///
/// 1. Koyu temada şık dolgusu Kulis (`#2B2C32`) zemine (`#121214`) çok yakındı
///    ve kenarı yoktu; şıklar "ışığı sönük" okunuyordu.
/// 2. Soru metni 800 ağırlıktaydı; 700 ağırlıklı şıklara göre fazla bağırıyordu.
/// 3. Soru+şık grubu alt çubuktan ~195 pt yukarıda duruyordu (bildirim payı
///    160): altta ölü boşluk.
/// 4. Şıklar 52 yüksek, aralarında 8 pt.
///
/// ## Niçin sessiz kalırdı
///
/// Renk, kenar ve boşluk değerleri hiçbir testte sayıyla sınanmıyordu; eski
/// testler yalnız "şık var, dokunulur" diyordu. Burada belirteç kontrastı,
/// ölçülen yükseklik/aralık ve alt boşluk sayıyla sabitlenir.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  double lum(Color c) => c.computeLuminance();
  double ratio(Color a, Color b) {
    final hi = lum(a) > lum(b) ? lum(a) : lum(b);
    final lo = lum(a) > lum(b) ? lum(b) : lum(a);
    return (hi + 0.05) / (lo + 0.05);
  }

  test('gece şık dolgusu zeminden bir ton açık, kenarı belirgin', () {
    const t = SahneTokens.night;
    expect(t.optionFill, isNot(t.s2), reason: 'Kulis yerine bir ton açık');
    expect(ratio(t.optionFill, t.bg), greaterThan(ratio(t.s2, t.bg)));
    expect(
      ratio(t.optionEdge, t.bg),
      greaterThanOrEqualTo(2.0),
      reason: '1 px kenar zeminden seçilmeli',
    );
    expect(ratio(t.tx, t.optionFill), greaterThanOrEqualTo(7));
    expect(ratio(t.tx, t.optionLetterFill), greaterThanOrEqualTo(7));
    // Gündüz değişmedi.
    expect(SahneTokens.day.optionFill, SahneTokens.day.s2);
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = kPhoneSize,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: kPhoneInsets,
            viewPadding: kPhoneInsets,
            textScaler: TextScaler.linear(textScale),
          ),
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom().copyWith(questionCount: 1),
            questions: repository.questions.take(1).toList(),
            enableTimer: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('şıklar en az 56 yüksek, aralarında 12; grup dikeyde ortalı', (
    tester,
  ) async {
    await pump(tester);
    final tiles = find.byType(QuizOptionTile);
    final n = tiles.evaluate().length;
    expect(n, greaterThanOrEqualTo(2));
    for (var i = 0; i < n; i++) {
      expect(
        tester.getSize(tiles.at(i)).height,
        greaterThanOrEqualTo(quizOptionMinHeight),
      );
      if (i > 0) {
        expect(
          tester.getTopLeft(tiles.at(i)).dy -
              tester.getBottomLeft(tiles.at(i - 1)).dy,
          closeTo(12, 0.5),
        );
      }
    }
    // Tur 8b: grup, üst çubuk ile alt bildirim payı arasında ORTALI (üst ve
    // alt boşluk yaklaşık eşit); 48 pt kuralı yanlıştı, geri alındı.
    final scroll = find.byKey(const ValueKey('quiz-portrait-scroll'));
    final top = tester
        .getTopLeft(find.byKey(const ValueKey('quiz-answer-content')))
        .dy;
    final topGap = top - tester.getTopLeft(scroll).dy;
    final bottomGap =
        tester.getBottomLeft(scroll).dy -
        quizAnchorNoticeReserve -
        tester.getBottomLeft(tiles.last).dy;
    expect(
      (topGap - bottomGap).abs(),
      lessThanOrEqualTo(48),
      reason: 'üst=$topGap alt=$bottomGap eşit olmalı',
    );
  });

  testWidgets('tost görünürken son şıkkın alt kenarı tostun üstünde kalır', (
    tester,
  ) async {
    await pump(tester);
    final context = tester.element(find.byType(QuizOptionTile).first);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('İlk deneme yanlışsa bir hak daha'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final toast = tester.getRect(find.byType(SnackBar));
    final last = tester.getRect(find.byType(QuizOptionTile).last);
    expect(last.bottom, lessThanOrEqualTo(toast.top));
  });

  for (final (name, size, scale) in [
    ('320 genişlik', const Size(320, 640), 1.0),
    ('%200 yazı', kPhoneSize, 2.0),
  ]) {
    testWidgets('$name: taşma/kırılma yok', (tester) async {
      await pump(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.byType(QuizOptionTile), findsWidgets);
    });
  }
}
