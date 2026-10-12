import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

import 'support/widget_test_helpers.dart';

/// Başlangıç yolu III (2026-10-08): meslek, şehir, alışveriş, sağlık, okul,
/// ulaşım, geçmiş zaman.
///
/// ## Kusur
///
/// Başlangıç yolu (alfabe, aile, kendini tanıtma, selamlaşma II) yeni
/// başlayana ilk günü doyuruyordu ama yol orada bitiyordu: renk, vücut, ev,
/// giysi, hava gibi ilk haftanın sözcük alanları ve "kî/çi/ku" soruları ya da
/// "ez diçim" gibi fiil çekimi yoktu; ilk dersleri bitiren öğrenen yeni ders
/// bulamadan ya zor derslere (zamir, fiil) atlıyor ya da bırakıyordu.
///
/// ## Niçin sessiz kalıyordu
///
/// Hiçbir şey "yol sıfırdan başlayana ne kadar uzanıyor" diye ölçmüyordu;
/// `beginner_track_test.dart` yalnız ilk dört dersi sabitliyordu. Yeni bir dersin
/// soruları derse etiketlenmezse (learningLessonId) kısa test sessizce genel
/// havuzdan dolar, sözlüğe girmezse dokunmalı sözlük o dersin sözcüklerinde
/// hiç açılmaz.
///
/// ## Bekçi
///
/// Yedi yeni ders derse bağlı derse bağlı çoktan seçmeli/boşluk doldurma/cümle kurma (sayılar `_mc`,
/// `_fib`, `_wo`) taşır; bankada tam 121 kayıt vardır; her dersin
/// slaytları, sözlük kaynağı ve kısa testi vardır; boşluk doldurma/cümle kurma
/// sorularındaki her Kurmancî sözcük sözlüktedir; öğrenme yolunda yeni
/// dersler önceki başlangıç derslerinden SONRA gelir.
const _lessons = [
  'jobs_1',
  'city_1',
  'shopping_1',
  'health_1',
  'school_1',
  'transport_1',
  'past_1',
];

/// Derse bağlı çoktan seçmeli/boşluk doldurma/cümle kurma sayısı. «Kîjan hevok
/// rast e?» gibi genel istemler bankada zaten varsa kalite kapısı tam yineleme
/// (kritik) sayar; o kopyalar alınmadı (past_1 yalnız 4 çoktan seçmeliyle kaldı).
const _mc = {
  'jobs_1': 5,
  'city_1': 7,
  'shopping_1': 8,
  'health_1': 8,
  'school_1': 7,
  'transport_1': 8,
  'past_1': 4,
};
const _fib = {
  'jobs_1': 6,
  'city_1': 6,
  'shopping_1': 6,
  'health_1': 6,
  'school_1': 6,
  'transport_1': 6,
  'past_1': 6,
};
const _wo = {
  'jobs_1': 5,
  'city_1': 5,
  'shopping_1': 5,
  'health_1': 4,
  'school_1': 3,
  'transport_1': 5,
  'past_1': 5,
};

const _policy = QuestionContentPolicy();

String _fold(String value) => LearnerLexicon.foldForSearch(value);

List<String> _tokens(String text) => RegExp(
  r"[^\s,.?!:;()/\x27\x22“”«»–—]+",
).allMatches(_fold(text)).map((m) => m.group(0)!).toList();

void main() {
  late List<QuizQuestion> playable;

  setUpAll(() {
    playable = QuestionBankLoader.instance.allQuestions
        .where(_policy.isPlayable)
        .toList();
  });

  test('her yeni ders derse bağlı >= 8 çoktan seçmeli, >= 6 boşluk doldurma, '
      '>= 5 cümle kurma taşır', () {
    for (final id in _lessons) {
      Iterable<QuizQuestion> of(QuestionType type) => playable.where(
        (q) => q.type == type && q.metadata?.learningLessonId == id,
      );
      expect(of(QuestionType.multipleChoice).length, _mc[id], reason: '$id MC');
      expect(
        of(QuestionType.fillInBlank).length,
        _fib[id],
        reason: '$id boşluk',
      );
      expect(
        of(QuestionType.wordOrdering).length,
        _wo[id],
        reason: '$id cümle',
      );
    }
    expect(
      playable.where((q) => q.id.startsWith('dersler3_2026_10_08_')).length,
      121,
    );
  });

  test('yeni dersler yolda eski başlangıç derslerinden sonra gelir', () async {
    final repository = freshMockRepository();
    final lessons = await repository.loadLessonsByCategory('everyday');
    final ids = lessons.map((l) => l.id).toList();
    for (final id in _lessons) {
      expect(ids, contains(id));
      expect(ids.indexOf(id), greaterThan(ids.indexOf('verbs_1')));
      expect(await repository.loadLessonSlides(id), hasLength(5), reason: id);
    }
    expect(ids.indexOf('jobs_1'), lessThan(ids.indexOf('past_1')));
    expect(ids.last, 'past_1', reason: 'geçmiş zaman en sonda');
    expect(ids.indexOf('verbs_1'), lessThan(ids.indexOf('jobs_1')));
    final orders = lessons.map((l) => l.order).toList();
    expect(orders, [...orders]..sort());
    expect(orders.toSet().length, orders.length);
  });

  test('her yeni ders sözlük kaynağı ve kısa testi taşır', () async {
    final repository = freshMockRepository();
    for (final id in _lessons) {
      expect(LearnerLexicon.sources.containsKey(id), isTrue, reason: id);
      expect(
        LearnerLexicon.entriesForSource(id).length,
        greaterThanOrEqualTo(8),
        reason: '$id sözlük',
      );
      final questions = await repository.loadLearningQuizQuestions(
        category: 'Ziman',
        learningLessonId: id,
        limit: 5,
      );
      expect(questions, hasLength(5), reason: id);
      expect(
        questions.every((q) => q.metadata?.learningLessonId == id),
        isTrue,
        reason: '$id kısa testi başka dersin sorusunu karıştırıyor',
      );
    }
  });

  test('boşluk doldurma ve cümle kurma sözcükleri sözlükte vardır', () {
    final dictionary = {
      for (final entry in LearnerLexicon.entries) ...[
        ..._tokens(entry.termKu),
        for (final form in entry.forms) ..._tokens(form),
      ],
    };
    final missing = <String>{};
    for (final q in playable.where(
      (q) =>
          q.id.startsWith('dersler3_2026_10_08_') &&
          q.type != QuestionType.multipleChoice,
    )) {
      final sentence = q.type == QuestionType.wordOrdering
          ? q.correctAnswer
          : RegExp(r'"([^"]*___[^"]*)"')
                .firstMatch(q.prompt)!
                .group(1)!
                .replaceAll('___', q.correctAnswer);
      for (final token in _tokens(sentence)) {
        if (!dictionary.contains(token)) missing.add('$token (${q.id})');
      }
    }
    expect(missing, isEmpty, reason: 'sözlükte olmayan sözcük: $missing');
  });

  test('aynı derste cümle kurma ve boşluk doldurma hedefleri tekrar etmez', () {
    for (final id in _lessons) {
      final fib = playable
          .where(
            (q) =>
                q.type == QuestionType.fillInBlank &&
                q.metadata?.learningLessonId == id,
          )
          .map((q) => q.correctAnswer)
          .toList();
      final prompts = playable
          .where(
            (q) =>
                q.type == QuestionType.fillInBlank &&
                q.metadata?.learningLessonId == id,
          )
          .map((q) => q.prompt)
          .toSet();
      expect(prompts.length, fib.length, reason: '$id aynı cümle iki kez');
    }
  });
}
