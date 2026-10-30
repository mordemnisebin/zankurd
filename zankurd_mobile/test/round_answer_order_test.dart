import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

const _question = QuizQuestion(
  id: 'repeat-question',
  category: 'test',
  prompt: 'Test',
  answers: ['one', 'two', 'three', 'four'],
  correctAnswer: 'one',
  promptTr: 'Test TR',
  answersTr: ['bir', 'iki', 'üç', 'dört'],
  correctAnswerTr: 'bir',
  explanation: '',
);

void main() {
  test(
    'istemci algoritması sessizce sapabiliyordu; sabit platform vektörü yoktu',
    () {
      final q = _question.forRound('room-vector');
      expect(q.displayAnswers.map(q.optionKeyForAnswer), ['D', 'C', 'A', 'B']);
    },
  );

  test(
    'aynı soru ezberleniyordu; eski bekçi yalnız soru kimliğine bakıyordu',
    () {
      final orders = <String>{};
      final positions = List<int>.filled(4, 0);
      for (var i = 0; i < 10000; i++) {
        final q = _question.forRound('match-$i');
        orders.add(q.displayAnswers.join('|'));
        positions[q.displayAnswers.indexOf(q.correctAnswer)]++;
        expect(q.displayAnswers.toSet(), q.answers.toSet());
      }
      expect(
        orders.length,
        24,
        reason: 'Yalnız döndürme değil tüm permütasyonlar',
      );
      for (final count in positions) {
        expect(count / 10000, inInclusiveRange(.22, .28), reason: '$positions');
      }
    },
  );

  test('iki istemci ve yeniden açma sapıyordu; eski test maç taşımıyordu', () {
    for (var i = 0; i < 100; i++) {
      final first = _question.forRound('room-$i');
      final second = QuizQuestion.fromJson(
        _question.toJson(),
      ).forRound('room-$i');
      expect(second.displayAnswers, first.displayAnswers);
      expect(first.displayAnswers, first.displayAnswers);
      expect(() => first.displayAnswers.add('x'), throwsUnsupportedError);
      expect(first.toJson(), _question.toJson());
    }
  });

  test('dil ve cevap açılması sıra kaydırıyordu; kopyalar kapsam dışıydı', () {
    for (var i = 0; i < 100; i++) {
      final ku = _question.forRound('duel-$i');
      final tr = ku.localized(isKu: false);
      expect(
        tr.displayAnswers.map(tr.optionKeyForAnswer),
        ku.displayAnswers.map(ku.optionKeyForAnswer),
      );
      final revealed = ku.withRevealedAnswer(correctAnswer: 'one');
      expect(revealed.displayAnswers, ku.displayAnswers);
      expect(revealed.localized(isKu: false).displayAnswers, tr.displayAnswers);
      for (final q in [ku, tr]) {
        for (final shown in q.displayAnswers) {
          final key = 'ABCD'[q.answers.indexOf(shown)];
          expect(q.optionKeyForAnswer(shown), key);
          expect(q.answerForOptionKey(key), shown);
        }
      }
    }
  });

  test(
    'özel türler yanlışlıkla karışıyordu; yalnız doğru yanlış sınanıyordu',
    () {
      for (final type in QuestionType.values.where(
        (t) => t != QuestionType.multipleChoice,
      )) {
        final q = _question.copyWith(type: type);
        for (var i = 0; i < 20; i++) {
          expect(q.forRound('match-$i').displayAnswers, q.answers);
        }
      }
    },
  );

  test(
    'sayısal sıra dilde sapıyordu; çeviride sayısal olmayan şık sınanmıyordu',
    () {
      final numeric = _question.copyWith(
        answers: ['20.', '19.', '15.', '17.'],
        correctAnswer: '20.',
      );
      final baseline = numeric.displayAnswers;
      for (var i = 0; i < 50; i++) {
        final q = numeric.forRound('match-$i');
        expect(q.displayAnswers, baseline);
        final tr = q.localized(isKu: false);
        expect(
          tr.displayAnswers.map(tr.optionKeyForAnswer),
          q.displayAnswers.map(q.optionKeyForAnswer),
        );
      }
    },
  );

  test(
    'iki şıklı çoktan seçmeli ezberleniyordu; yalnız dört şık sınanıyordu',
    () {
      final q = _question.copyWith(answers: ['one', 'two']);
      final orders = {
        for (var i = 0; i < 100; i++)
          q.forRound('two-$i').displayAnswers.join('|'),
      };
      expect(orders, {'one|two', 'two|one'});
    },
  );

  test('boş maç kimliği sabit sırayı gizliyordu; bağlam doğrulanmıyordu', () {
    expect(() => _question.forRound(''), throwsArgumentError);
    expect(() => _question.forRound('  '), throwsArgumentError);
  });
}
