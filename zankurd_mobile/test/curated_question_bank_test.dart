import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/curated_question_bank.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';

void main() {
  test('curated questions are approved, unique and Kurmanci-first', () {
    final ids = curatedQuestionBank.map((question) => question.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(curatedQuestionBank, isNotEmpty);

    for (final question in curatedQuestionBank) {
      expect(question.metadata?.reviewStatus, ReviewStatus.approved);
      expect(question.metadata?.dialect, 'Kurmancî');
      expect(question.metadata?.sourceTitle, isNotEmpty);
      expect(question.metadata?.sourceReference, isNotEmpty);
      expect(question.answers, contains(question.correctAnswer));
      expect(question.answers.toSet(), hasLength(question.answers.length));
      expect(question.prompt, isNot(contains('Türkçe')));
    }
  });

  test('curated movement bank includes visual and true-false variety', () {
    expect(
      curatedQuestionBank.where((q) => q.type.name == 'visual'),
      isNotEmpty,
    );
    expect(
      curatedQuestionBank.where((q) => q.type.name == 'trueFalse'),
      isNotEmpty,
    );
  });

  test(
    'curated movement bank distributes questions across source families',
    () {
      final sourceTitles = curatedQuestionBank
          .map((question) => question.metadata?.sourceTitle)
          .whereType<String>()
          .toSet();
      expect(sourceTitles, hasLength(greaterThanOrEqualTo(4)));
      expect(sourceTitles.any((title) => title.contains('ANF')), isTrue);
      expect(sourceTitles.any((title) => title.contains('KJAR')), isTrue);
      expect(
        sourceTitles.any((title) => title.contains('Kongra Star')),
        isTrue,
      );
      expect(sourceTitles.any((title) => title.contains('Jineolojî')), isTrue);
    },
  );

  test(
    'movement questions are distributed across the full learning taxonomy',
    () {
      final categories = curatedQuestionBank
          .map((question) => question.category)
          .toSet();
      expect(
        categories,
        containsAll(<String>[
          'Ziman',
          'Dîrok',
          'Cografya',
          'Muzîk',
          'Siyaset',
          'Edebiyat',
          'Çand',
          'Paradigma',
        ]),
      );
    },
  );

  test('curated prompts do not reuse the same question shape', () {
    String shape(String prompt) => prompt
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final shapes = curatedQuestionBank.map((q) => shape(q.prompt)).toList();
    expect(shapes.toSet(), hasLength(shapes.length));
  });
}
