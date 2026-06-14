import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/offline_question_bank.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  const validCategories = {
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
  };

  test('all question ids are unique', () {
    final ids = offlineQuestionBank.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every correct answer exists among its options', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.answers,
        contains(question.correctAnswer),
        reason: '${question.id}: correctAnswer not in answers',
      );
    }
  });

  test('every question uses a known category', () {
    for (final question in offlineQuestionBank) {
      expect(
        validCategories,
        contains(question.category),
        reason: '${question.id}: unknown category ${question.category}',
      );
    }
  });

  test('difficulties stay within 1-5', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.difficulty,
        inInclusiveRange(1, 5),
        reason: '${question.id}: difficulty ${question.difficulty}',
      );
    }
  });

  test('answer options are unique per question', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.answers.toSet().length,
        question.answers.length,
        reason: '${question.id}: duplicate options',
      );
    }
  });

  test('true/false questions use Rast/Şaş options', () {
    for (final question in offlineQuestionBank.where(
      (q) => q.type == QuestionType.trueFalse,
    )) {
      expect(question.answers, [
        'Rast',
        'Şaş',
      ], reason: '${question.id}: unexpected true/false options');
    }
  });

  test('bank grew past 1100 questions', () {
    expect(offlineQuestionBank.length, greaterThan(1100));
  });
}
