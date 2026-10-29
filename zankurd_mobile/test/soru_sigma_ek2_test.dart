import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_fit.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/okunur_boyut.dart';
import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// SORU SIĞMA BEKÇİSİ — EK 2 (Astra 2. inceleme, 2026-10-29): küçük
/// birimlerin sınır davranışı. `soru_sigma_test` / `soru_sigma_ek_test`
/// ekran düzeyini ölçer; burada:
///  * `QuizFitLine` sıfır/dar genişlikte çökmez, punto pozitif, çizilen ≥ 11;
///  * doğrusal olmayan TextScaler'da taban punto ve dokunma tabanı (≥ 48);
///  * `QuizFit` önbelleği kademe alanlarını/ölçekleyiciyi/metni karıştırmaz;
///  * seyirci yüzdesi ve rakip rozetleri önceki şıkkın yazı alanına girmez;
///  * oda şeridi 320/375'te 4 oyuncu, 5 haneli puan, 1,3× yazıda taşmaz.

const _s320 = Size(320, 568);
const _s375 = Size(375, 667);

void _yuzey(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  const pad = FakeViewPadding(top: 20);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);
}

/// Doğrusal OLMAYAN ölçekleyici (Android 14 yazı tipi ölçeği gibi): küçük
/// puntolar görece daha çok büyür.
class _NonLinear extends TextScaler {
  const _NonLinear();

  @override
  double scale(double fontSize) => fontSize * 1.1 + 3;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(14) / 14;
}

const _uzun = QuizQuestion(
  id: 'ek2-1',
  category: 'Ziman',
  prompt: 'Di rêzimana Kurmancî de peyva «navdêr» ji bo çi tê bikaranîn?',
  promptTr: 'Dilbilgisinde «isim» sözcüğü ne için kullanılır?',
  answers: ['Ji bo navê kes', 'Ji bo kirinê', 'Ji bo rengê', 'Ji bo girêdanê'],
  answersTr: ['Kişi adı için', 'Eylem için', 'Renk için', 'Bağlamak için'],
  correctAnswer: 'Ji bo navê kes',
  correctAnswerTr: 'Kişi adı için',
  explanation: 'Navdêr navê kes e.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets(
    'QuizFitLine: sıfır/dar genişlikte istisna yok, çizilen ≥ 11 pt',
    (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final w in [0.0, 1.0, 2.9, 8.0, 40.0, 90.0, 400.0]) {
          await tester.pumpWidget(
            testShell(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: SizedBox(
                    width: w,
                    child: const QuizFitLine(
                      'Tolhildan Mawal Ezîzo Uzun Ad',
                      maxLines: 2,
                      style: TextStyle(fontSize: 14, fontFamily: 'Onest'),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: 'w=$w x$scale');
          final text = tester.widget<Text>(find.byType(Text));
          final size = text.style!.fontSize!;
          expect(size, greaterThan(0), reason: 'w=$w x$scale pozitif punto');
          expect(
            size * scale,
            greaterThanOrEqualTo(11 - 0.05),
            reason: 'w=$w x$scale çizilen ≥ 11 pt',
          );
        }
      }
    },
  );

  test('QuizFit: doğrusal olmayan ölçekleyicide taban punto ve dokunma', () {
    const nl = _NonLinear();
    final fit = QuizFit.forLevel(QuizFit.maxLevel, nl);
    expect(fit.questionScale * nl.scale(22), greaterThanOrEqualTo(17 - 0.01));
    expect(fit.optionScale * nl.scale(16), greaterThanOrEqualTo(15 - 0.01));
    for (var k = 0; k <= QuizFit.maxLevel; k++) {
      expect(
        QuizFit.forLevel(k, nl).optionMinHeight,
        greaterThanOrEqualTo(48),
        reason: 'kademe $k: Android 48 dp dokunma tabanı',
      );
    }
  });

  testWidgets('QuizFit önbelleği: ölçekleyici ve metin anahtarda', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    double est(QuizFit f, TextScaler b, String prompt) => f.estimate(
      context: ctx,
      prompt: prompt,
      answers: const ['bir', 'iki', 'üç', 'dört'],
      width: 300,
      base: b,
      listenButton: false,
      titleLineBudget: 3,
    );
    const lin = TextScaler.linear(1);
    const nl = _NonLinear();
    const kisa = 'Soru bir iki üç dört beş';
    final a = est(QuizFit.forLevel(3, lin), lin, kisa);
    expect(est(QuizFit.forLevel(3, lin), lin, kisa), a, reason: 'önbellek');
    expect(
      est(QuizFit.forLevel(3, nl), nl, kisa),
      isNot(a),
      reason: 'ölçekleyici anahtarda',
    );
    expect(
      est(
        QuizFit.forLevel(3, lin),
        lin,
        '$kisa altı yedi sekiz dokuz on on bir on iki on üç on dört on beş '
        'on altı on yedi on sekiz on dokuz yirmi',
      ),
      greaterThan(a),
      reason: 'metin içerikle ayrışır',
    );
    expect(
      est(QuizFit.forLevel(0, lin), lin, kisa),
      isNot(est(QuizFit.forLevel(6, lin), lin, kisa)),
      reason: 'kademe alanları anahtarda',
    );
  });

  for (final level in [0, 2, 4, 6]) {
    testWidgets('rozetler önceki şıkka girmez (kademe $level)', (tester) async {
      _yuzey(tester, _s375);
      final fit = QuizFit.forLevel(level, const TextScaler.linear(1));
      await tester.pumpWidget(
        testShell(
          child: QuizFitScope(
            fit: fit,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
                child: Column(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: fit.optionGap),
                        child: QuizOptionTile(
                          key: ValueKey('t$i'),
                          index: i,
                          answer: 'Kısa şık $i',
                          selected: false,
                          correct: false,
                          disabled: false,
                          onTap: () {},
                          audiencePercent: i == 1 ? 0.42 : null,
                          opponentNamesWhoSelected: i == 2
                              ? const ['Tolhildan Mawal Ezîzo', 'Rakip Uzun']
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final (i, ad) in [(1, '42'), (2, 'Tolhildan')]) {
        final tile = tester.getRect(find.byKey(ValueKey('t$i')));
        final prev = tester.getRect(find.byKey(ValueKey('t${i - 1}')));
        final mark = tester.getRect(
          find
              .ancestor(
                of: find.textContaining(ad).first,
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          mark.top,
          greaterThanOrEqualTo(prev.bottom - fit.optionVPad - 0.5),
          reason: 'kademe $level: rozet önceki şıkkın yazı alanına giriyor',
        );
        expect(mark.left, greaterThanOrEqualTo(tile.left - 0.5));
        expect(mark.right, lessThanOrEqualTo(tile.right + 0.5));
      }
    });
  }

  for (final (size, scale) in const [
    (_s320, 1.0),
    (_s320, 1.3),
    (_s375, 1.0),
    (_s375, 1.3),
  ]) {
    testWidgets(
      'oda şeridi: 4 oyuncu, 5 haneli puan, ${size.width.toInt()} @$scale '
      '— taşma ve kırpma yok',
      (tester) async {
        const room = GameRoom(
          id: 'ek-r',
          name: 'Oda',
          code: 'ZK-EK',
          category: 'Ziman',
          status: RoomStatus.active,
          questionCount: 2,
          players: [
            Player(name: 'Tolhildan Mawal', score: 12345, state: 'Hazır'),
            Player(name: 'Rakip Oyuncu', score: 99999, state: 'Hazır'),
            Player(name: 'Üçüncü', score: 8765, state: 'Hazır'),
            Player(name: 'Dördüncü', score: 54321, state: 'Hazır'),
          ],
          maxPlayers: 4,
          isCustom: true,
          hostId: 'h',
        );
        _yuzey(tester, size);
        SharedPreferences.setMockInitialValues({
          'zankurd.quiz_tutorial.seen': true,
          'zankurd.navTour.seen': true,
        });
        final repository = freshMockRepository();
        await tester.pumpWidget(
          testShell(
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: QuizScreen(
                  repository: repository,
                  room: room,
                  questions: const [_uzun, _uzun],
                  enableTimer: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        final strip = find.byKey(const ValueKey('quiz-crowd-top3'));
        expect(strip, findsOneWidget);
        for (final e in find.byType(RichText).evaluate()) {
          final r = e.renderObject;
          if (r is RenderParagraph && r.didExceedMaxLines) {
            fail('kırpılmış: "${r.text.toPlainText()}"');
          }
        }
        final header = tester.getRect(
          find.byKey(const ValueKey('quiz-crowd-header')),
        );
        expect(tester.getRect(strip).right, lessThanOrEqualTo(header.right));
        // Kapışma U13/U15: ad ve puan okunur alt sınırın altına küçülmez
        // (kart yazı ölçeği 1.15'te tavanlanır).
        final effective = kOkunurAltSinir * (scale > 1.15 ? 1.15 : scale);
        for (var rank = 1; rank <= 4; rank++) {
          expect(
            renderedFontSize(
              tester,
              find.byKey(ValueKey('quiz-crowd-name-$rank')),
            ),
            greaterThanOrEqualTo(effective - 0.01),
            reason: '$rank. oyuncunun adı küçültülmüş',
          );
        }
      },
    );
  }
}
