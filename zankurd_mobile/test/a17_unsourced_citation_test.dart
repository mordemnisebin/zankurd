import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// A17: künye ya gerçekdir ya yoktur. Uydurma kaynak yasak; Wikipedia /
/// Iranica künyesi olan expansion kaydı oynanabilir olur.
void main() {
  test('kaynaksız metadata künye iddia etmez', () {
    expect(const QuestionMetadata().hasCitableSource, isFalse);
    expect(const QuestionMetadata(sourceTitle: '  ').hasCitableSource, isFalse);
    expect(
      const QuestionMetadata(
        sourceTitle: 'Encyclopaedia Iranica',
      ).hasCitableSource,
      isTrue,
    );
  });

  test('expansion_2026_08_19 gerçek künye taşır ve oynanabilir', () {
    final raw =
        jsonDecode(
              File(
                'assets/data/expansion_2026_08_19_questions.json',
              ).readAsStringSync(),
            )
            as List<dynamic>;
    expect(raw, hasLength(77));

    const policy = QuestionContentPolicy();
    for (final item in raw) {
      final question = QuizQuestion.fromJson(item as Map<String, dynamic>);
      final meta = question.metadata ?? const QuestionMetadata();
      expect(meta.hasCitableSource, isTrue, reason: question.id);
      expect(
        meta.sourceReference,
        anyOf(startsWith('https://en.wikipedia.org/'), contains('iranica')),
        reason: question.id,
      );
      expect(meta.reviewStatus, ReviewStatus.approved, reason: question.id);
      expect(policy.isPlayable(question), isTrue, reason: question.id);
    }
  });

  test('mock depo dar portları karşılar', () {
    final repo = MockZanKurdRepository();
    expect(repo, isA<SoloQuizPort>());
    expect(repo, isA<LivePlayPort>());
  });
}
