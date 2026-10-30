import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
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

  testWidgets('üç haneli turda kapsül 120→100→99→9→0 aynı genişlikte', (
    tester,
  ) async {
    double? width;
    for (final s in [120, 100, 99, 10, 9, 0]) {
      await tester.pumpWidget(
        testShell(
          child: Center(
            child: SahneStageTimer(
              secondsLeft: s,
              maxSeconds: 120,
              semanticLabel: '$s',
            ),
          ),
        ),
      );
      final w = tester.getSize(find.byType(SahneStageTimer)).width;
      width ??= w;
      expect(w, moreOrLessEquals(width, epsilon: 0.5), reason: '$s sn');
    }
  });

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

  /// ## C12 — lobi oyuncu sırası cihazdan cihaza farklı
  ///
  /// Klasik (kalabalık olmayan) odanın lobisi de puana göre sıralanıyordu;
  /// herkes 0 puandayken Dart'ın kararsız `sort`u eşitleri her cihazda farklı
  /// diziyordu. T7: lobide sıra sunucunun katılma anahtarıdır; oyunda
  /// eşit puanlar da aynı anahtarla çözülür. Tarih yoksa kimlik belirler.
  group('C12 oyuncu sırası', () {
    Player p(String id, int score) =>
        Player(id: id, name: id, score: score, state: '');

    test('lobide zaman yoksa oyuncu kimliği belirleyicidir', () {
      final input = [p('ali', 0), p('bero', 0), p('dlan', 0), p('cano', 0)];
      expect(orderRoomPlayersForDisplay(input, lobby: true).map((e) => e.id), [
        'ali',
        'bero',
        'cano',
        'dlan',
      ]);
    });

    test('oyunda puana göre, eşitlikte sunucu katılma anahtarı', () {
      final input = [
        for (var i = 0; i < 40; i++) p('o$i', i % 3 == 0 ? 10 : 0),
      ];
      final out = orderRoomPlayersForDisplay(input, lobby: false);
      final tens = [
        for (final e in input)
          if (e.score == 10) e.id,
      ];
      final zeros = [
        for (final e in input)
          if (e.score == 0) e.id,
      ];
      expect(out.map((e) => e.id).toList(), [
        ...(tens..sort()),
        ...(zeros..sort()),
      ]);
    });
  });

  /// ## C31 — dönüş bildirimi soruyu örtüyordu, sayaç 19'dan 8'e atlıyordu
  ///
  /// Üstteki kaplama bildirim soru kartının ilk satırını ~4 sn örtüyordu.
  /// Şimdi üst çubuktaki mod çipi kısa süre kehribar "Süre işliyor" olur:
  /// hiçbir şeyi örtmez ve çip değişince künye ile gövde yerinden oynamaz.
  /// Sunucu saati gelmeden sayaç yerel tam süreyi gösterip sonra atlıyordu;
  /// şimdi "–" (aynı genişlik).
  group('C31', () {
    for (final ku in [false, true]) {
      for (final width in [375.0, 402.0]) {
        testWidgets('mod çipi vurgusu yerleşimi oynatmaz ${ku ? 'KU' : 'TR'} '
            '$width', (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          Future<(Rect, double)> pumpWith(String label, bool hi) async {
            await tester.pumpWidget(
              testShell(
                languageProvider: ku ? kurmanciLang() : null,
                child: SahneStageScaffold(
                  onClose: () {},
                  body: const SizedBox(key: ValueKey('tur3-body'), height: 10),
                  center: QuizStageCenter(
                    category: 'Edebiyat',
                    index: 3,
                    total: 7,
                    modeLabel: label,
                    modeHighlight: hi,
                  ),
                  score: const SahneStageTimer(
                    secondsLeft: 8,
                    semanticLabel: '8',
                  ),
                ),
              ),
            );
            await tester.pump();
            return (
              tester.getRect(find.byKey(const ValueKey('quiz-stage-kicker'))),
              tester.getTopLeft(find.byKey(const ValueKey('tur3-body'))).dy,
            );
          }

          final normal = await pumpWith(ku ? 'Bi dorê' : 'Sırayla', false);
          final hi = await pumpWith(ku ? 'Dem didome' : 'Süre işliyor', true);
          expect(hi.$1.top, moreOrLessEquals(normal.$1.top, epsilon: 0.5));
          expect(
            hi.$1.height,
            moreOrLessEquals(normal.$1.height, epsilon: 0.5),
          );
          expect(hi.$2, moreOrLessEquals(normal.$2, epsilon: 0.5));
          final chip = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(const ValueKey('quiz-mode-chip')),
              matching: find.byType(RichText),
            ),
          );
          expect(chip.didExceedMaxLines, isFalse, reason: 'çip kesilmez');
        });
      }
    }

    testWidgets('sayaç beklemede duraklatma simgesi ve aynı genişlikte', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SahneStageTimer(
                  key: ValueKey('a'),
                  secondsLeft: 19,
                  semanticLabel: '19',
                  pending: true,
                ),
                SahneStageTimer(
                  key: ValueKey('b'),
                  secondsLeft: 8,
                  semanticLabel: '8',
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('19'), findsNothing);
      expect(find.byKey(const ValueKey('stage-timer-paused')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('a'))).width,
        moreOrLessEquals(
          tester.getSize(find.byKey(const ValueKey('b'))).width,
          epsilon: 0.5,
        ),
      );
    });
  });

  /// ## Görselli soruda resim seri rozetinin üstüne biniyordu
  ///
  /// Asılı "×n Üst üste" rozeti gövdenin üst payına boyanır; görselli soruda
  /// resim gövdenin en üstünden başladığı için ikisi üst üste geliyordu.
  /// Görselli soruda rozet çizilmez; görselsiz soruda yine görünür.
  testWidgets('görselli soruda seri rozeti yok, görselsizde var', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
    QuizQuestion q(int n, {String? image}) => QuizQuestion(
      id: 'tur3-$n',
      category: 'Ziman',
      prompt: 'Pirsa hejmar $n?',
      answers: const ['rast', 'şaş-a', 'şaş-b', 'şaş-c'],
      correctAnswer: 'rast',
      explanation: '',
      imageUrl: image,
    );
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [
            q(1),
            q(2),
            q(3),
            q(4, image: 'asset://assets/zankurd.webp'),
            q(5),
          ],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> answer(String text) async {
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 3; i++) {
      await answer('rast');
    }
    // 4. soru görselli: seri ×3 ama rozet çizilmez.
    expect(find.textContaining('×3'), findsNothing);
    await answer('rast');
    // 5. soru görselsiz: seri ×4 rozeti görünür.
    expect(find.textContaining('×4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
