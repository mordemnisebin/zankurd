import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// 2026-07-25 denetim bulgusu: cümle kurma soruları hem hiçbir parser
/// tarafından üretilmiyor hem de üretilseler `correct_answer_missing` ile
/// oynanamaz sayılıyordu (doğru cevap tam cümle, `answers` ise kelime havuzu).

const _policy = QuestionContentPolicy();

QuizQuestion _wordOrdering({
  required List<String> answers,
  required String correctAnswer,
}) {
  return QuizQuestion(
    id: 'wo-test',
    category: 'Ziman',
    prompt: 'Hevokê rêz bike',
    answers: answers,
    correctAnswer: correctAnswer,
    explanation: '',
    type: QuestionType.wordOrdering,
  );
}

void main() {
  test('kelime havuzu doğru cümleyle örtüşen soru oynanabilir', () {
    final question = _wordOrdering(
      answers: ['Ez', 'diçim', 'malê'],
      correctAnswer: 'Ez diçim malê',
    );
    expect(_policy.validate(question), isEmpty);
    expect(_policy.isPlayable(question), isTrue);
  });

  test('havuzda fazla kelime varsa soru elenir', () {
    final question = _wordOrdering(
      answers: ['Ez', 'diçim', 'malê', 'îro'],
      correctAnswer: 'Ez diçim malê',
    );
    expect(_policy.validate(question), contains('word_ordering_pool_mismatch'));
  });

  test('havuzda eksik kelime varsa soru elenir', () {
    final question = _wordOrdering(
      answers: ['Ez', 'diçim'],
      correctAnswer: 'Ez diçim malê',
    );
    expect(_policy.validate(question), contains('word_ordering_pool_mismatch'));
  });

  test('tek kelimelik "cümle" elenir', () {
    final question = _wordOrdering(answers: ['Ez', 'Ez'], correctAnswer: 'Ez');
    expect(
      _policy.validate(question),
      contains('word_ordering_requires_two_words'),
    );
  });

  /// 2026-08-07: banka onaylandı ve tip artık gerçekten oynanıyor.
  ///
  /// Sekiz cümlenin sekizi de tek tek denetlendi (`metadata.reviewNote`
  /// içinde her birinin dilbilgisi gerekçesi yazılı) ve `approved` yapıldı.
  /// Öncesinde bu bekçi `isPlayable`ın **false** olmasını sabitliyordu:
  /// banka yapısal olarak geçiyor ama editör onayı beklediği için oyuncuya
  /// hiç ulaşmıyordu. Yani uygulama beş soru tipi duyururken bunlardan biri
  /// fiilen boştu.
  ///
  /// Onaylamanın alternatifi tipi özellik listesinden düşürmekti; sekiz
  /// cümle de doğru olduğu için düşürmek yerine açmak seçildi.
  test('cümle kurma asset bankası onaylı ve oynanabilir', () async {
    final raw = await File(
      'assets/data/sentence_building_questions.json',
    ).readAsString();
    final decoded = jsonDecode(raw) as List;
    final questions = decoded
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(questions, isNotEmpty);
    final ids = questions.map((q) => q.id).toSet();
    expect(ids.length, questions.length, reason: 'Tekrar eden kimlik var');

    for (final q in questions) {
      expect(q.type, QuestionType.wordOrdering, reason: '${q.id} yanlış tipte');
      expect(_policy.validate(q), isEmpty, reason: q.id);
      expect(
        _policy.isPlayable(q),
        isTrue,
        reason:
            '${q.id} oyuncuya ulaşmıyor. `metadata.reviewStatus` `approved` '
            'değilse soru sessizce elenir ve tip yine boş kalır.',
      );
    }
  });

  test('kelime havuzu ile doğru cümle her kayıtta birebir örtüşüyor', () async {
    // Yapısal kural `validate` içinde de var; burada açıkça ölçülüyor çünkü
    // bu banka artık oynanıyor ve havuz-cümle uyuşmazlığı doğrudan çözülemez
    // bir soru üretir: ya artık kelime kalır ya eksik kelime istenir.
    final raw = await File(
      'assets/data/sentence_building_questions.json',
    ).readAsString();
    final questions = (jsonDecode(raw) as List)
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final q in questions) {
      final pool = List<String>.of(q.answers)..sort();
      final sentence = q.correctAnswer.split(RegExp(r'\s+'))
        ..removeWhere((t) => t.isEmpty)
        ..sort();
      expect(
        pool,
        sentence,
        reason:
            '${q.id}: kelime havuzu «${q.answers.join(" / ")}» ile doğru '
            'cümle «${q.correctAnswer}» örtüşmüyor',
      );
    }
  });
}
