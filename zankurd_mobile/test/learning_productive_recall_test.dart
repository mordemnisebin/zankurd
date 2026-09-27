import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/learning_productive_recall.dart';

QuizQuestion _question({
  String id = 'q1',
  ReviewStatus status = ReviewStatus.approved,
  bool eligible = true,
}) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'Di Kurmancî de dijwateya "dirêj" çi ye?',
  promptTr: 'Kurmancîde "dirêj" sözcüğünün zıt anlamlısı nedir?',
  answers: const ['Kurt', 'Fireh', 'Giran', 'Nerm'],
  answersTr: const ['Kurt', 'Fireh', 'Giran', 'Nerm'],
  correctAnswer: 'Kurt',
  correctAnswerTr: 'Kurt',
  acceptedAnswers: const ['kurt'],
  acceptedAnswersTr: const ['kurt'],
  explanation: 'Dirêj û kurt dijwate ne.',
  metadata: QuestionMetadata(
    reviewStatus: status,
    productiveRecallEligible: eligible,
  ),
);

void main() {
  group('LearningProductiveRecall', () {
    test(
      'yalnız açıkça uygun ve onaylı MC sorusunu yazmalı hatırlamaya çevirir',
      () {
        final transformed = LearningProductiveRecall.transform(_question());

        expect(transformed.type, QuestionType.fillInBlank);
        expect(transformed.answers, ['Kurt']);
        expect(transformed.answersTr, ['Kurt']);
        expect(transformed.correctAnswer, 'Kurt');
        expect(transformed.acceptedAnswers, ['kurt']);
        expect(transformed.prompt, contains('dirêj'));
      },
    );

    test('opt-in olmayan veya onaylı olmayan soruya dokunmaz', () {
      final notEligible = _question(eligible: false);
      final needsReview = _question(status: ReviewStatus.needsReview);

      expect(
        LearningProductiveRecall.transform(notEligible),
        same(notEligible),
      );
      expect(
        LearningProductiveRecall.transform(needsReview),
        same(needsReview),
      );
    });

    test('zaten üretken soru türünü yeniden yazmaz', () {
      final original = _question().copyWith(type: QuestionType.wordOrdering);

      expect(LearningProductiveRecall.transform(original), same(original));
    });

    test('5 soruda üretken hatırlamayı bir normal sorudan sonra öne alır', () {
      final input = [
        _question(id: 'a', eligible: false),
        _question(id: 'b', eligible: false),
        _question(id: 'c', eligible: false),
        _question(id: 'd'),
        _question(id: 'e', eligible: false),
      ];

      final ordered = LearningProductiveRecall.orderForLearning(input);

      expect(ordered.map((q) => q.id), ['a', 'd', 'b', 'c', 'e']);
    });

    test(
      '10 soruda en fazla iki üretken hatırlamayı 2. ve 5. konuma yayar',
      () {
        final input = [
          _question(id: 'a', eligible: false),
          _question(id: 'b', eligible: false),
          _question(id: 'c'),
          _question(id: 'd', eligible: false),
          _question(id: 'e', eligible: false),
          _question(id: 'f'),
          _question(id: 'g', eligible: false),
          _question(id: 'h'),
          _question(id: 'i', eligible: false),
          _question(id: 'j', eligible: false),
        ];

        final ordered = LearningProductiveRecall.orderForLearning(input);

        expect(ordered[1].id, 'c');
        expect(ordered[4].id, 'f');
        expect(
          ordered.map((q) => q.id).toSet(),
          input.map((q) => q.id).toSet(),
        );
        expect(ordered.map((q) => q.id).where((id) => id == 'h'), hasLength(1));
      },
    );
  });

  test('productiveRecallEligible metadata JSON round-trip korunur', () {
    const meta = QuestionMetadata(
      reviewStatus: ReviewStatus.approved,
      productiveRecallEligible: true,
    );

    final restored = QuestionMetadata.fromJson(meta.toJson());

    expect(restored.productiveRecallEligible, isTrue);
    expect(restored.isEmpty, isFalse);
  });

  test('opt-in seti yalnız on üç onaylı Ziman sorusudur', () {
    final raw =
        jsonDecode(
              File('assets/data/editorial_questions.json').readAsStringSync(),
            )
            as List<dynamic>;
    final optedIn = raw.cast<Map<String, dynamic>>().where((question) {
      final metadata = question['metadata'] as Map<String, dynamic>?;
      return metadata?['productiveRecallEligible'] == true;
    }).toList();

    expect(optedIn.map((question) => question['id']).toSet(), {
      'edit_ziman_0001',
      'edit_ziman_0003',
      'edit_ziman_0005',
      'edit_ziman_0006',
      'edit_ziman_0013',
      'edit_ziman_0014',
      'edit_ziman_0016',
      'edit_ziman_0024',
      'edit_ziman_0028',
      'edit_ziman_0031',
      'edit_ziman_0032',
      'edit_ziman_0039',
      'edit_ziman_0046',
    });
    for (final question in optedIn) {
      expect(question['category'], 'Ziman');
      expect(question['type'], 'multipleChoice');
      expect((question['metadata'] as Map)['reviewStatus'], 'approved');
    }
  });
}
