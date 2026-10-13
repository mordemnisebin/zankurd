import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

import 'support/widget_test_helpers.dart';

/// Başlangıç yolu II (2026-10-08): renkler, vücut, giysiler, ev, hava durumu,
/// soru sözcükleri, temel fiiller.
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
/// Yedi yeni ders derse bağlı 11 (verbs_1) ya da 8 çoktan seçmeli, 6 boşluk doldurma ve
/// 5 cümle kurma taşır; bankada tam 136 kayıt vardır; her dersin
/// slaytları, sözlük kaynağı ve kısa testi vardır; boşluk doldurma/cümle kurma
/// sorularındaki her Kurmancî sözcük sözlüktedir; öğrenme yolunda yeni
/// dersler önceki başlangıç derslerinden SONRA gelir.
const _lessons = [
  'colors_1',
  'body_1',
  'home_1',
  'clothes_1',
  'weather_1',
  'questions_1',
  'verbs_1',
];
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
      // verbs_1: «Kîjan hevok rast e?» istemi clothes_1'de zaten var; ikinci
      // kopya kalite kapısında tam yineleme (kritik) sayıldığı için bankaya
      // alınmadı, bu yüzden 7 kalmıştı. 2026-10-13: slayttaki çekimlerden
      // dört somut soru eklendi (27-30), kısa testte yedekle 9+ olsun diye;
      // 7 soruluk ders 5 soruluk testi tekrarsız doldursa da yedeği yoktu.
      expect(
        of(QuestionType.multipleChoice).length,
        id == 'verbs_1' ? 11 : 8,
        reason: '$id MC',
      );
      expect(of(QuestionType.fillInBlank).length, 6, reason: '$id boşluk');
      expect(of(QuestionType.wordOrdering).length, 5, reason: '$id cümle');
    }
    expect(
      playable.where((q) => q.id.startsWith('dersler2_2026_10_08_')).length,
      136, // 132 + 4 verbs_1 sorusu (2026-10-13)
    );
  });

  test('yeni dersler yolda eski başlangıç derslerinden sonra gelir', () async {
    final repository = freshMockRepository();
    final lessons = await repository.loadLessonsByCategory('everyday');
    final ids = lessons.map((l) => l.id).toList();
    for (final id in _lessons) {
      expect(ids, contains(id));
      expect(ids.indexOf(id), greaterThan(ids.indexOf('everyday_3')));
      expect(await repository.loadLessonSlides(id), hasLength(5), reason: id);
    }
    expect(ids.indexOf('colors_1'), lessThan(ids.indexOf('clothes_1')));
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
          q.id.startsWith('dersler2_2026_10_08_') &&
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
