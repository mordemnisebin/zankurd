import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';

import 'support/widget_test_helpers.dart';

/// Yeni iki dilli bankanın oyuncuya ULAŞAN hâlinin bekçisi.
///
/// ## Niçin ayrı bir bekçi
///
/// `expansion_activation_test` bankanın yükleyiciden çıktığını doğrular —
/// veri doğrudur. Ama veri doğruyken ekran yanlış olabilir: soru Türkçe
/// seçilip şıklar Kurmancî kalabilir, açıklama kural motoruna düşüp
/// bankadaki elle yazılmış metin hiç kullanılmayabilir (2026-07-27'de tam
/// bu oldu: Kurmancî turda özet `Şirove: <Türkçe cümle>` gösteriyordu).
///
/// Bu bankanın kaydı özellikle riskli, çünkü **her alanın iki sürümü var**.
/// `QuizScreen` soruyu baştan `localized(isKu:)` ile yansıtıyor
/// (`quiz_screen.dart:389`) ve `AnswerRecord` o yansıtılmış kayıttan
/// üretiliyor; bu zincirin herhangi bir halkası kopsa oyuncu karışık dilde
/// bir sınav görür. Bekçi zinciri uçtan uca yürütür.
///
/// Ölçüler `large_text_overflow_test` ile aynı: 320x568 (desteklenen en dar
/// cihaz) ve 390x844 (iPhone 14), %100 ve %200 yazı.
void main() {
  late MockZanKurdRepository repository;
  late List<QuizQuestion> expansion;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
    repository = freshMockRepository();
    const families = ['cinema_', 'tech_core_', 'tech_invent_', 'ziman_x_'];
    expansion = QuestionBankLoader.instance.allQuestions
        .where((q) => families.any(q.id.startsWith))
        .toList();
  });

  /// En uzun metinli kayıtlar seçilir: taşma en önce orada görünür.
  List<QuizQuestion> worstCase(int count) {
    final sorted = [...expansion]
      ..sort((a, b) {
        int weight(QuizQuestion q) =>
            q.prompt.length +
            (q.promptTr?.length ?? 0) +
            q.answers.fold<int>(0, (s, a) => s + a.length) +
            q.getLocalizedExplanation(true).length +
            q.getLocalizedExplanation(false).length;
        return weight(b).compareTo(weight(a));
      });
    return sorted.take(count).toList();
  }

  Future<void> pumpQuiz(
    WidgetTester tester, {
    required bool isKu,
    required List<QuizQuestion> questions,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testShell(
        languageProvider: isKu ? kurmanciLang() : turkishLang(),
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: questions,
            enableTimer: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  List<AnswerRecord> recordsFor(List<QuizQuestion> questions, bool isKu) => [
    for (final raw in questions)
      () {
        // Ekranın yaptığının aynısı: önce yansıt, sonra kaydı üret.
        final q = raw.localized(isKu: isKu);
        return AnswerRecord(
          id: q.id,
          category: q.category,
          prompt: q.promptText,
          answers: q.answers,
          correctAnswer: q.correctAnswer,
          selectedAnswer: q.answers.firstWhere((a) => a != q.correctAnswer),
          explanation: q.explanation,
          explanationKu: q.explanationKu,
          explanationTr: q.explanationTr,
        );
      }(),
  ];

  for (final isKu in [true, false]) {
    final lang = isKu ? 'Kurmancî' : 'Türkçe';

    testWidgets('$lang turda soru ve şıklar seçilen dilde geliyor', (
      tester,
    ) async {
      final questions = worstCase(3);
      await pumpQuiz(tester, isKu: isKu, questions: questions);

      final first = questions.first.localized(isKu: isKu);
      expect(
        find.text(first.promptText),
        findsOneWidget,
        reason:
            '$lang turda soru metni yansıtılmamış. `localized(isKu:)` '
            'zinciri kopmuş olabilir.',
      );
      for (final answer in first.displayAnswers) {
        expect(
          find.text(answer),
          findsWidgets,
          reason: '$lang turda "$answer" şıkkı ekranda yok.',
        );
      }
      // Diğer dilin metni sızmamalı: karışık dilde sınav olmaz.
      final other = questions.first.localized(isKu: !isKu);
      if (other.promptText != first.promptText) {
        expect(
          find.text(other.promptText),
          findsNothing,
          reason: '$lang turda öteki dilin soru metni de basılmış.',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$lang turda tüm sorular cevaplanıp tur tamamlanıyor', (
      tester,
    ) async {
      final questions = worstCase(3);
      await pumpQuiz(tester, isKu: isKu, questions: questions);

      // `QuizScreen` soruları karıştırır, dolayısıyla listedeki i'ninci
      // soru ekrandaki i'ninci soru DEĞİLDİR. Akış ekranda ne varsa onun
      // üzerinden yürütülür; sıraya bel bağlamak testi kırılgan yapar.
      var answered = 0;
      for (var step = 0; step < questions.length; step++) {
        final tiles = find.byType(QuizOptionTile);
        if (tiles.evaluate().isEmpty) break;
        await tester.ensureVisible(tiles.first);
        await tester.tap(tiles.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        answered++;
        final next = find.byKey(const ValueKey('quiz-next-button'));
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1200));
        }
      }
      expect(
        answered,
        questions.length,
        reason:
            '$lang turda ${questions.length} sorunun yalnız $answered tanesi '
            'cevaplanabildi; akış ortada duruyor.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$lang review ekranı bankadaki açıklamayı gösteriyor', (
      tester,
    ) async {
      final questions = worstCase(3);
      final records = recordsFor(questions, isKu);

      await tester.pumpWidget(
        testShell(
          languageProvider: isKu ? kurmanciLang() : turkishLang(),
          child: ReviewScreen(records: records, room: repository.createRoom()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      final authored = questions.first.getLocalizedExplanation(isKu);
      expect(
        find.textContaining(
          authored.substring(0, authored.length.clamp(0, 30)),
          findRichText: true,
        ),
        findsWidgets,
        reason:
            '$lang review ekranında bankanın elle yazılmış açıklaması yok; '
            'metin kural motorundan üretiliyor olabilir.',
      );
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(320, 568), Size(390, 844)]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets(
          '$lang quiz ${size.width.toInt()}px %${(scale * 100).toInt()} '
          'yazıda taşmıyor',
          (tester) async {
            await pumpQuiz(
              tester,
              isKu: isKu,
              questions: worstCase(1),
              size: size,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
