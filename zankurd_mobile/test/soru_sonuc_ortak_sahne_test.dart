// 2026-10-28 JÜRİ K6 / K6+ / K7 / K7+: soru sahnesi, sonuç ve cevaplar ekranı.
//
// ## Kusur
//
// * Soru ekranı her modda başka bir ekran gibiydi: üst bant konunun rengine
//   boyanıyordu (Dil → turkuaz, öğrenme → yeşil), soru metni boş gradyanın
//   ortasında yüzüyor, üstte ekranın üçte biri boş kalıyordu; cevaptan sonra
//   yalnız turuncu bir "Sonraki" vardı.
// * Sonuç ekranı bütün zemini bordoya boyuyordu ("kırmızı = hata" okunuyor,
//   başarı anı kırmızıydı); turuncu "Tekrar oyna" dahil ilk görünümde
//   açıklama listesi ekranı itiyordu.
// * Cevaplar ekranı her karta dört şık + üç satırlık açıklama basıyordu.
//
// ## Niçin sessiz kalırdı
//
// Hiçbiri taşma ya da istisna değildir; her test "soru var, şık var" der.
// Yalnız renk (bant), konum (soru üstü), sayı (turuncu düğme) ve görünürlük
// ölçülürse yakalanır.
//
// ## Geçersiz kılınan eski kararlar
//
// * 2026-10-20 "konu bandı" (kategori renkli üst bant) → kalktı; mod tek
//   küçük çip.
// * 2026-10-20 "şıklar alta oturur, soru boş alanda ortalanır" (anchorHeight)
//   → kalktı; soru ÜSTTEN başlar.
// * 2026-10-20 sonuç sahnesi mod renginde gradyan (Boyax/Zimrût) → nötr
//   sahne.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

const _records = [
  AnswerRecord(
    id: 'r1',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek', 'yol', 'dağ'],
    correctAnswer: 'su',
    selectedAnswer: 'su',
    explanation: '«av» Türkçede «su» demektir.',
    explanationKu: '«av» bi Tirkî dibe «su».',
    explanationTr: '«av» Türkçede «su» demektir.',
  ),
  AnswerRecord(
    id: 'r2',
    category: 'Çand',
    prompt: 'Çay li kîjan firaxê tê vexwarin?',
    answers: ['bardak', 'kase', 'sênî', 'beroş'],
    correctAnswer: 'bardak',
    selectedAnswer: 'kase',
    explanation: 'Çay genellikle «bardak» ile içilir.',
    explanationKu: 'Çay bi gelemperî di «bardak»ê de tê vexwarin.',
    explanationTr: 'Çay genellikle «bardak» ile içilir.',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
  });

  Future<void> pumpQuiz(
    WidgetTester tester, {
    QuizExperience experience = QuizExperience.competition,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: repo.createRoom(),
          questions: repo.questions.take(2).toList(),
          experience: experience,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final experience in QuizExperience.values) {
    testWidgets('K6: ${experience.name} sahnesinde konu renkli bant yok, mod '
        'çipi var', (tester) async {
      await pumpQuiz(tester, experience: experience);
      expect(
        find.byKey(const ValueKey('sahne-stage-band')),
        findsNothing,
        reason: 'konu renkli (turkuaz/yeşil) üst bant geri gelmiş',
      );
      expect(
        find.byKey(const ValueKey('sahne-stage-band-floor')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('quiz-mode-chip')), findsOneWidget);
    });
  }

  testWidgets('K6: soru bloğu ekranın üst %45\'inde başlar, açık kartta', (
    tester,
  ) async {
    await pumpQuiz(tester);
    final card = find.byKey(const ValueKey('quiz-prompt-card'));
    expect(card, findsOneWidget);
    final top = tester.getTopLeft(card).dy;
    expect(top, lessThan(844 * 0.45), reason: 'soru bloğu üstü $top');
    // Üstte dev boş alan yok: kart üst çubuğun hemen altında.
    expect(top, lessThan(200));
    // Açık yüzey: koyu sahnede açık kart (yüksek karşıtlık).
    final box = tester.widget<Container>(card);
    final fill = (box.decoration as ShapeDecoration).color!;
    expect(fill.computeLuminance(), greaterThan(0.8));
  });

  testWidgets('K6: şıklar ≥ 52 yüksek, aralık 8-12', (tester) async {
    await pumpQuiz(tester);
    final rects = [
      for (final e in find.byType(QuizOptionTile).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects.length, greaterThanOrEqualTo(2));
    for (final r in rects) {
      expect(r.height, greaterThanOrEqualTo(52));
    }
    for (var i = 1; i < rects.length; i++) {
      final gap = rects[i].top - rects[i - 1].bottom;
      expect(gap, inInclusiveRange(8, 12));
    }
  });

  testWidgets('K6+: cevaptan sonra geri bildirim şeridi + Sonraki', (
    tester,
  ) async {
    await pumpQuiz(tester, experience: QuizExperience.learning);
    expect(find.byKey(const ValueKey('quiz-feedback-correct')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-feedback-wrong')), findsNothing);
    // İlk şık.
    await tester.tap(find.byType(QuizOptionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    final strip = find.byWidgetPredicate(
      (w) =>
          w.key == const ValueKey('quiz-feedback-correct') ||
          w.key == const ValueKey('quiz-feedback-wrong'),
    );
    expect(strip, findsOneWidget);
    expect(
      find.descendant(
        of: strip,
        matching: find.byKey(const ValueKey('quiz-next-button')),
      ),
      findsOneWidget,
      reason: '"Sonraki" aynı şeritte olmalı',
    );
  });

  testWidgets('K7: sonuç nötr sahne, tek turuncu birincil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repo,
          room: repo.createRoom(),
          score: 240,
          correctCount: 1,
          wrongCount: 1,
          totalQuestions: 2,
          bestStreak: 1,
          coinsAwarded: 30,
          answerRecords: _records,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // Tam ekran bordo/Boyax gradyanı yok.
    expect(find.byKey(const ValueKey('sahne-stage-scene')), findsNothing);
    final primaries = find.byWidgetPredicate(
      (w) => w is SahneButton && w.isPrimary,
    );
    expect(primaries, findsOneWidget);
    // Cevaplar varsayılan kapalı; "Cevapları gör" açar.
    expect(find.byType(ResultExplanationEntry), findsNothing);
    final toggle = find.byKey(const ValueKey('result-see-answers'));
    await tester.scrollUntilVisible(
      toggle,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(find.byType(ResultExplanationEntry), findsWidgets);
  });

  testWidgets('K7+: cevaplar kartı yalnız kendi + doğru şıkkı gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: ReviewScreen(room: repo.createRoom(), records: _records),
      ),
    );
    await tester.pump();
    // r2: seçilen "kase" (yanlış) + doğru "bardak" görünür; öteki şıklar gizli.
    expect(find.text('bardak'), findsOneWidget);
    expect(find.text('kase'), findsOneWidget);
    expect(find.text('sênî'), findsNothing);
    expect(find.text('beroş'), findsNothing);
    // "Tüm şıkları gör" hepsini açar.
    await tester.tap(find.byKey(const ValueKey('review-show-all-r2')));
    await tester.pump();
    expect(find.text('sênî'), findsOneWidget);
  });
}
