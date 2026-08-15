import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';
import 'package:zankurd_mobile/src/utils/free_text_answer_matcher.dart';

const _assetPath = 'assets/data/fill_in_blank_2026_08_questions.json';
const _policy = QuestionContentPolicy();

void main() {
  late List<QuizQuestion> questions;

  setUpAll(() {
    final rows = jsonDecode(File(_assetPath).readAsStringSync()) as List;
    questions = rows
        .cast<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList(growable: false);
  });

  test('banka tam 20 benzersiz yazılı Ziman sorusu taşır', () {
    expect(questions, hasLength(20));
    expect(questions.map((q) => q.id).toSet(), hasLength(20));

    for (final question in questions) {
      expect(question.category, 'Ziman', reason: question.id);
      expect(question.type, QuestionType.fillInBlank, reason: question.id);
      expect(question.answers, hasLength(1), reason: question.id);
      expect(question.answers.single, question.correctAnswer);
      expect(
        question.acceptsAnswer(question.correctAnswer),
        isTrue,
        reason: question.id,
      );
    }
  });

  test('her iki dilde tek boşluk ve tam öğrenme açıklaması vardır', () {
    for (final question in questions) {
      expect(
        RegExp(r'___').allMatches(question.prompt),
        hasLength(1),
        reason: '${question.id}: Kurmancî soru',
      );
      expect(
        RegExp(r'___').allMatches(question.promptTr ?? ''),
        hasLength(1),
        reason: '${question.id}: Türkçe soru',
      );
      expect(question.hasTurkishTranslation, isTrue, reason: question.id);
      expect(
        question.explanationKu?.trim(),
        isNotEmpty,
        reason: '${question.id}: Kurmancî açıklama',
      );
      expect(
        question.explanationTr?.trim(),
        isNotEmpty,
        reason: '${question.id}: Türkçe açıklama',
      );
    }
  });

  test('sorular onaylı, kaynaklı ve oyuncuya gerçekten ulaşabilir', () {
    for (final question in questions) {
      final metadata = question.metadata;
      expect(
        metadata?.reviewStatus,
        ReviewStatus.approved,
        reason: question.id,
      );
      expect(metadata?.dialect, 'Kurmancî', reason: question.id);
      expect(metadata?.sourceTitle?.trim(), isNotEmpty, reason: question.id);
      expect(
        metadata?.sourceReference?.trim(),
        isNotEmpty,
        reason: question.id,
      );
      expect(metadata?.reviewedBy?.trim(), isNotEmpty, reason: question.id);
      expect(metadata?.reviewedAt?.trim(), isNotEmpty, reason: question.id);
      expect(metadata?.qualityVersion, greaterThanOrEqualTo(2));
      expect(_policy.validate(question), isEmpty, reason: question.id);
      expect(_policy.isPlayable(question), isTrue, reason: question.id);
    }
  });

  test('alternatif yanıtlar boş, yinelenen veya anlamsız değildir', () {
    for (final question in questions) {
      final normalized = <String>{
        normalizeFreeTextAnswer(question.correctAnswer),
      };
      for (final answer in question.acceptedAnswers) {
        expect(answer.trim(), isNotEmpty, reason: question.id);
        expect(
          normalized.add(normalizeFreeTextAnswer(answer)),
          isTrue,
          reason: '${question.id}: yinelenen alternatif «$answer»',
        );
        expect(question.acceptsAnswer(answer), isTrue, reason: question.id);
      }
    }
  });

  test('oyuncuya görünen alıntılar tek guillemet kuralını izler', () {
    final rows = (jsonDecode(File(_assetPath).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    const fields = [
      'prompt',
      'promptTr',
      'explanation',
      'explanationKu',
      'explanationTr',
    ];

    for (final row in rows) {
      for (final field in fields) {
        final value = row[field] as String? ?? '';
        expect(value, isNot(contains('“')), reason: '${row['id']}/$field');
        expect(value, isNot(contains('”')), reason: '${row['id']}/$field');
      }
    }
  });
}
