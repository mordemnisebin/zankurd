/// Cümle kurma: `acceptedAnswers` ile ikinci geçerli dizilim kabul edilir.
///
/// ## Kusur
///
/// `QuizQuestion.matchAnswer` cümle kurma için yalnız `candidate ==
/// correctAnswer` bakıyordu; `acceptedAnswers` yalnız boşluk doldurmada
/// okunuyordu. Kurmancîde serbest sıralı bir cümlenin ("duh ez hatim malê"
/// / "ez duh hatim malê") ikinci doğru dizilimi, veride yazılsa bile,
/// YANLIŞ sayılırdı (2026-10-16 denetimi).
///
/// ## Niçin sessizdi
///
/// Veri tarafında bu alan cümle kurma soruları için hiç doldurulmadı
/// (126 sorunun 0'ında var), yani yanlış sayılan bir alternatif hiç
/// görülmedi; şema alanı ise kabul edilmiş gibi duruyordu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

QuizQuestion _question({List<String> accepted = const []}) => QuizQuestion(
  id: 'wo-1',
  category: 'Ziman',
  prompt: 'Cümleyi kur',
  answers: const ['duh', 'ez', 'hatim', 'malê'],
  correctAnswer: 'duh ez hatim malê',
  acceptedAnswers: accepted,
  explanation: '',
  type: QuestionType.wordOrdering,
);

void main() {
  test('kanonik dizilim her zaman kabul edilir', () {
    expect(_question().acceptsAnswer('duh ez hatim malê'), isTrue);
  });

  test('alternatif yazılmamışsa başka dizilim yanlıştır', () {
    expect(_question().acceptsAnswer('ez duh hatim malê'), isFalse);
  });

  test('acceptedAnswers içindeki ikinci dizilim doğru sayılır', () {
    final question = _question(accepted: const ['ez duh hatim malê']);
    expect(question.acceptsAnswer('ez duh hatim malê'), isTrue);
    expect(question.acceptsAnswer('duh ez hatim malê'), isTrue);
    expect(question.acceptsAnswer('hatim ez duh malê'), isFalse);
  });

  test('yalnız boşluk farkı yok sayılır, büyük harf katlanmaz', () {
    final question = _question(accepted: const ['ez duh hatim malê']);
    expect(question.acceptsAnswer(' ez  duh hatim   malê '), isTrue);
    expect(question.acceptsAnswer('Ez duh hatim malê'), isFalse);
  });

  test('alternatif dizilim havuzun kelimelerinin yer değiştirmesi olmalı', () {
    const policy = QuestionContentPolicy();
    expect(
      policy.validate(_question(accepted: const ['ez duh hatim malê'])),
      isNot(contains('word_ordering_accepted_not_permutation')),
    );
    expect(
      policy.validate(_question(accepted: const ['ez duh hatim mal'])),
      contains('word_ordering_accepted_not_permutation'),
    );
  });

  // Jüri onaylı (Gemini 3.8 Flash öneri, Grok 4.7 oy; 2026-10-16) serbest
  // zarf sırası: bu dört soruda öteki doğal dizilim de doğru sayılmalı.
  test('jüri onaylı dört alternatif dizilim bankada kabul edilir', () {
    const expected = {
      'baslangic_2026_10_06_questions.json': {
        'baslangic_2026_10_06_0152': 'ez îro baş im',
      },
      'dersler2_2026_10_08_questions.json': {
        'dersler2_2026_10_08_0091': 'îro hewa xweş e',
      },
      'dersler3_2026_10_08_questions.json': {
        'dersler3_2026_10_08_0119': 'ez duh hatim malê',
      },
      'sentence_building_questions.json': {'wo-ku-008': 'hewa îro germ e'},
    };
    const policy = QuestionContentPolicy();
    for (final entry in expected.entries) {
      final raw = jsonDecode(
        File('assets/data/${entry.key}').readAsStringSync(),
      );
      final items = (raw is List ? raw : raw['questions']) as List;
      for (final want in entry.value.entries) {
        final json = items.cast<Map<String, dynamic>>().firstWhere(
          (q) => q['id'] == want.key,
        );
        final question = QuizQuestion.fromJson(json);
        expect(question.acceptsAnswer(want.value), isTrue, reason: want.key);
        expect(
          policy.validate(question),
          isNot(contains('word_ordering_accepted_not_permutation')),
        );
      }
    }
  });
}
