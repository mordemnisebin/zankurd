import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';

import 'support/widget_test_helpers.dart';

/// Sözlük dokunuşu (2026-10-06).
///
/// ## Kusur
///
/// Başlangıç yolu geri bildirimi: öğrenen sorudaki ya da slayttaki bir
/// sözcüğün anlamını bilmiyor; sözlük ayrı bir ekranda, aratmak için sözcüğü
/// ezberden yazmak gerekiyor. Sözcüğe dokununca anlam açılmalı — ama ASLA
/// cevabı vermeden.
///
/// ## Niçin sessiz kalabilirdi
///
/// Sızıntı iki yerden gelir: sorulan terimin ("Dûr" bi Tirkî çi ye?) anlamı
/// cevabın kendisidir; doğru cevabın sözcükleri de sözlükte durur. Yarışta
/// (oda, düello) bu bir hile olurdu. Hiçbir şey bunu ölçmüyordu.
///
/// ## Bekçi
///
/// Cevaptan önce sorulan terim ve doğru cevabın sözcükleri dokunulabilir
/// DEĞİL; cevaptan sonra açılır. Yarışta (`QuizExperience.competition`)
/// hiçbir sözcük dokunulabilir değil. Sözlükte olmayan sözcük dokunulamaz.
const _translate = QuizQuestion(
  id: 'lookup-translate',
  category: 'Ziman',
  prompt: '"Dûr" bi Tirkî çi ye?',
  promptTr: '"Dûr" Türkçesi nedir?',
  answers: ['Yakın', 'Büyük', 'Küçük', 'Uzak'],
  correctAnswer: 'Uzak',
  explanation: '"Dûr" uzak demektir.',
  type: QuestionType.multipleChoice,
);

const _fill = QuizQuestion(
  id: 'lookup-fill',
  category: 'Ziman',
  prompt: 'Hevokê temam bike: "Ev ___ ye." ("Bu anne.")',
  promptTr: 'Cümleyi tamamla: "Ev ___ ye." ("Bu anne.")',
  answers: ['dê'],
  correctAnswer: 'dê',
  explanation: '',
  type: QuestionType.fillInBlank,
);

Future<void> _open(
  WidgetTester tester,
  QuizQuestion question, {
  required QuizExperience experience,
}) async {
  final repository = freshMockRepository();
  await tester.pumpWidget(
    testShell(
      child: QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: [question],
        experience: experience,
        enableTimer: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _word(String folded) => find.byKey(ValueKey('lexicon-word-$folded'));

void main() {
  group('sözcük eşleme', () {
    test('tam eşleşme, biçim ve kök+ek (>= 4 harf)', () {
      expect(LearnerLexicon.lookup('Dûr')?.termKu, 'Dûr');
      expect(LearnerLexicon.lookup('dur')?.termKu, 'Dûr', reason: 'aksansız');
      expect(LearnerLexicon.lookup('malê')?.termKu, 'Mal', reason: 'biçim');
      expect(LearnerLexicon.lookup('welatên')?.termKu, 'Welat', reason: 'kök');
      expect(LearnerLexicon.lookup('qqqq'), isNull);
      expect(LearnerLexicon.lookup('xyz'), isNull);
      // 3 harfli kök önek olarak çalışmaz: `kurmanc` -> Kur(d) değil.
      expect(LearnerLexicon.lookup('baxa'), isNull);
    });
  });

  group('cevap sızdırma politikası', () {
    LexiconTapPolicy policy({
      bool enabled = true,
      bool answered = false,
      String type = 'multipleChoice',
      String prompt = '"Dûr" Türkçesi nedir?',
      String correct = 'Uzak',
      bool isKu = false,
    }) => LexiconTapPolicy.forQuestion(
      enabled: enabled,
      isKu: isKu,
      answered: answered,
      type: type,
      promptText: prompt,
      correctAnswer: correct,
    );

    test('yarış/oda/düello: kapalı', () {
      expect(policy(enabled: false).enabled, isFalse);
    });

    test('sorulan terim cevaptan önce engelli, sonra açık', () {
      expect(policy().blocked, contains('dur'));
      expect(policy(answered: true).blocked, isEmpty);
    });

    test('"bi Kurmancî çi ye" ve cümle kurma: kapalı', () {
      expect(
        policy(prompt: '"Uzak" bi Kurmancî çi ye?').enabled,
        isFalse,
        reason: 'terim şıklarda; şıklar hiç dokunulabilir değil',
      );
      expect(policy(type: 'wordOrdering').enabled, isFalse);
    });

    test('boşluk doldurmada doğru cevabın sözcükleri engelli', () {
      final p = policy(
        type: 'fillInBlank',
        prompt: 'Hevokê temam bike: "Ev ___ ye."',
        correct: 'dê',
      );
      expect(p.blocked, contains('de'));
      expect(p.mode, LexiconTapMode.firstQuote);
    });
  });

  group('quiz ekranı', () {
    testWidgets('öğrenme: cevaptan önce sorulan terim dokunulamaz, sonra '
        'açılır', (tester) async {
      await _open(tester, _translate, experience: QuizExperience.learning);
      expect(_word('dur'), findsNothing, reason: 'cevap sızardı');

      await tester.tap(find.text('Uzak'));
      await tester.pumpAndSettle();
      expect(_word('dur'), findsOneWidget);

      await tester.tap(_word('dur'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lexicon-entry-sheet')), findsOneWidget);
      expect(find.text('Uzak'), findsWidgets);
      expect(find.byKey(const ValueKey('lexicon-sheet-open')), findsOneWidget);
    });

    testWidgets('öğrenme: boşluk doldurmada sözlükteki sözcük açılır', (
      tester,
    ) async {
      await _open(tester, _fill, experience: QuizExperience.learning);
      expect(_word('ev'), findsOneWidget);
      expect(_word('ye'), findsOneWidget);
      // Türkçe gloss (ikinci tırnak) dokunulabilir değil.
      expect(_word('bu'), findsNothing);
      expect(_word('anne'), findsNothing);
      await tester.tap(_word('ev'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lexicon-entry-sheet')), findsOneWidget);
      expect(find.text('Bu'), findsWidgets);
    });

    testWidgets('yarış modunda hiçbir sözcük dokunulamaz', (tester) async {
      await _open(tester, _fill, experience: QuizExperience.competition);
      expect(_word('ev'), findsNothing);
      expect(_word('ye'), findsNothing);
    });

    testWidgets('yarışta cevaptan sonra da kapalı', (tester) async {
      await _open(tester, _translate, experience: QuizExperience.competition);
      await tester.tap(find.text('Uzak'));
      await tester.pumpAndSettle();
      expect(_word('dur'), findsNothing, reason: 'yarışta cevaptan sonra da');
    });

    testWidgets('sözlükte olmayan sözcük dokunulamaz', (tester) async {
      const q = QuizQuestion(
        id: 'lookup-unknown',
        category: 'Ziman',
        prompt: 'Hevokê temam bike: "Ev zzzzz ___ ye."',
        promptTr: 'Cümleyi tamamla: "Ev zzzzz ___ ye."',
        answers: ['dê'],
        correctAnswer: 'dê',
        explanation: '',
        type: QuestionType.fillInBlank,
      );
      await _open(tester, q, experience: QuizExperience.learning);
      expect(_word('zzzzz'), findsNothing);
      expect(_word('ev'), findsOneWidget);
    });
  });

  testWidgets(
    'ders slaydında başlık sözcüğü dokunulabilir, çiftler düz kalır',
    (tester) async {
      final repository = freshMockRepository();
      final lesson = (await repository.loadLessonsByCategory(
        'everyday',
      )).firstWhere((l) => l.id == 'alphabet_1');
      await tester.pumpWidget(
        testShell(
          child: LessonDetailScreen(lesson: lesson, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      // "Heşt tîp dengdêr in, ..." satırı: dengdêr sözlükte var.
      expect(_word('dengder'), findsOneWidget);
      // "• Dengdêr: Ünlü harf" çifti düz metin (yalnız başlık satırı bağlı).
      await tester.tap(_word('dengder'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lexicon-entry-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lexicon-sheet-open')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('lexicon-search-field')),
        findsOneWidget,
      );
      expect(find.text('Ünlü harf'), findsWidgets);
    },
  );
}
