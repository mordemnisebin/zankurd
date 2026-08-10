import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Tür enum'a eklenmişti ama quiz panelinde yalnız `wordOrdering` için özel
/// dal vardı. Bu yüzden bir `fillInBlank` kaydı metin alanı yerine tek şık
/// olarak görünür, kullanıcı özelliğin vaat ettiği cevabı yazamazdı.
const _question = QuizQuestion(
  id: 'fill-flow-1',
  category: 'Ziman',
  prompt: 'Ez ___ dixwînim.',
  answers: ['pirtûk'],
  correctAnswer: 'pirtûk',
  acceptedAnswers: ['pirtuk'],
  explanation: '',
  type: QuestionType.fillInBlank,
);

class _FailingSubmitRepository extends MockZanKurdRepository {
  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    throw StateError('çevrimdışı puanlama sınaması');
  }
}

class _RejectingSubmitRepository extends MockZanKurdRepository {
  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    return {'is_correct': false, 'points': 0, 'new_score': 0, 'new_streak': 0};
  }
}

void main() {
  testWidgets('yazılı soruda yalnız işe yarayan jokerler gösterilir', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final types = tester
        .widgetList<WildcardButton>(find.byType(WildcardButton))
        .map((button) => button.type)
        .toList(growable: false);
    expect(types, [WildcardType.doubleAnswer, WildcardType.changeQuestion]);
  });

  testWidgets(
    'boşluk doldurma quizde metin alanıyla çözülür ve toleranslı yanıt doğru sayılır',
    (tester) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [_question],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('fill-in-blank-input')), findsOneWidget);
      expect(find.byType(QuizOptionTile), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('fill-in-blank-input')),
        'PIRTUK',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fill-in-blank-result')),
        findsOneWidget,
      );
      expect(find.text('Doğru: pirtûk'), findsOneWidget);
    },
  );

  testWidgets(
    'repository hatasında yerel puanlama toleranslı yanıtı doğru sayar',
    (tester) async {
      final repository = _FailingSubmitRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [_question],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('fill-in-blank-input')),
        'PIRTUK',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
      await tester.pumpAndSettle();

      expect(find.text('110'), findsOneWidget);
    },
  );

  testWidgets('toleranslı doğru yanıt sonuç kaydında da doğru kalır', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      'PIRTUK',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
    await tester.pumpAndSettle();

    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.answerRecords.single.isCorrect, isTrue);
    expect(result.answerRecords.single.selectedAnswer, 'PIRTUK');
  });

  testWidgets('sonuç kaydı repository kararını korur ve ham yazımı saklar', (
    tester,
  ) async {
    final repository = _RejectingSubmitRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
          practice: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      'PIRTUK',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Doğru cevap: pirtûk'), findsOneWidget);
    expect(find.text('Doğru: pirtûk'), findsNothing);
    expect(find.text('Zor'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
    await tester.pumpAndSettle();

    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.answerRecords.single.isCorrect, isFalse);
    expect(result.answerRecords.single.selectedAnswer, 'PIRTUK');
  });

  testWidgets('çift cevap jokeri toleranslı doğru metni ilk yanlış sanmaz', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await repository.awardQuizCoins(
      score: 1000,
      correctCount: 20,
      totalQuestions: 20,
      bestStreak: 10,
      room: repository.createRoom().copyWith(id: 'seed-room'),
    );
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Çift Cevap'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      'PIRTUK',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Çift cevap: bir şık daha seç'), findsNothing);
    expect(find.byKey(const ValueKey('fill-in-blank-result')), findsOneWidget);
  });

  testWidgets('çift cevap ikinci denemeyi canlı ve şıksız bildirir', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await repository.awardQuizCoins(
      score: 1000,
      correctCount: 20,
      totalQuestions: 20,
      bestStreak: 10,
      room: repository.createRoom().copyWith(id: 'seed-room'),
    );
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Çift Cevap'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      'yanlış',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Çift cevap: bir cevap daha ver'), findsOneWidget);
    final liveRegion = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Çift cevap: bir cevap daha ver',
      ),
    );
    expect(liveRegion.excludeSemantics, isTrue);
  });

  testWidgets('çift cevap aynı yanlış metnin yeniden gönderilmesini engeller', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await repository.awardQuizCoins(
      score: 1000,
      correctCount: 20,
      totalQuestions: 20,
      bestStreak: 10,
      room: repository.createRoom().copyWith(id: 'seed-room'),
    );
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Çift Cevap'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('fill-in-blank-input'));
    await tester.enterText(input, 'yanlış');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
    await tester.enterText(input, 'yanlış');
    await tester.pump();
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('fill-in-blank-submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets(
    'alıştırma turu toleranslı doğru cevaptan sonra tekrar puanlaması sunar',
    (tester) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [_question],
            enableTimer: false,
            practice: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('fill-in-blank-input')),
        'PIRTUK',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Zor'), findsOneWidget);
      expect(find.text('Orta'), findsOneWidget);
      expect(find.text('Kolay'), findsOneWidget);
    },
  );

  for (final layout in <(String, Size)>[
    ('390×844 dikey telefon', const Size(390, 844)),
    ('844×390 yatay telefon', const Size(844, 390)),
  ]) {
    testWidgets('${layout.$1} sonucunda soru ve ana eylem kırpılmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(layout.$2);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [_question],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('fill-in-blank-input')),
        'yanlış',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
      await tester.pumpAndSettle();

      final promptRect = tester.getRect(find.text(_question.prompt));
      final resultRect = tester.getRect(
        find.byKey(const ValueKey('fill-in-blank-result')),
      );
      final nextRect = tester.getRect(
        find.byKey(const ValueKey('quiz-next-button')),
      );

      for (final rect in [promptRect, resultRect, nextRect]) {
        expect(rect.top, greaterThanOrEqualTo(0), reason: layout.$1);
        expect(
          rect.bottom,
          lessThanOrEqualTo(layout.$2.height),
          reason: layout.$1,
        );
      }
      expect(resultRect.top, greaterThan(promptRect.bottom));
      expect(tester.takeException(), isNull);
    });
  }
}
