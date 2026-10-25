import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/learning_lesson_aliases.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

import 'support/widget_test_helpers.dart';

/// Dil bilgisi derinliği (2026-10-25): izafe, gelecek zaman, emir kipi, aylar.
///
/// ## Kusur
///
/// Canlıda dil bilgisi yalnız zamirler (`cinavk`) ve olmak fiiliyle
/// (`lekera-bun`) duruyordu; şimdiki ve geçmiş zaman everyday yolundaydı.
/// Kurmancînin en sık yapısı olan izafe, gelecek zaman ve emir kipi hiç
/// öğretilmiyordu; ay adları dersi canlıda yoktu. Öğrenen "mala min",
/// "ez ê biçim", "were" gibi ilk haftanın kalıplarını hiçbir derste görmüyordu.
///
/// ## Niçin sessiz kalıyordu
///
/// Hiçbir bekçi "dil bilgisi kategorisi hangi yapıları kapsıyor" diye
/// ölçmüyordu; yol bekçileri (`beginner_track*_test`) yalnız everyday
/// derslerine bakıyordu. Yeni dersin soruları derse etiketlenmezse
/// (learningLessonId) kısa test sessizce sözlük dolgusuna düşer, sözlüğe
/// girmezse dokunmalı sözlük o dersin sözcüklerinde hiç açılmaz.
///
/// ## Bekçi
///
/// Dört yeni ders derse bağlı çoktan seçmeli/boşluk doldurma/cümle kurma
/// (sayılar `_mc`, `_fib`, `_wo`) taşır; bankada tam 76 kayıt vardır; her
/// dersin beş slaytı, sözlük kaynağı, sunucu eşlemesi ve kısa testi vardır;
/// boşluk doldurma/cümle kurma sorularındaki her Kurmancî sözcük sözlüktedir;
/// dersler kendi kategorisinde eski derslerden SONRA gelir.
const _lessons = {
  'izafe_1': 'grammar',
  'future_1': 'grammar',
  'imperative_1': 'grammar',
  'months_1': 'time',
};

const _slugs = {
  'izafe_1': 'izafe',
  'future_1': 'dema-be',
  'imperative_1': 'fermani',
  'months_1': 'mehen-sale',
};

const _mc = 8;
const _fib = 6;
const _wo = 5;

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

  test('her yeni ders derse bağlı $_mc çoktan seçmeli, $_fib boşluk doldurma, '
      '$_wo cümle kurma taşır', () {
    for (final id in _lessons.keys) {
      Iterable<QuizQuestion> of(QuestionType type) => playable.where(
        (q) => q.type == type && q.metadata?.learningLessonId == id,
      );
      expect(of(QuestionType.multipleChoice).length, _mc, reason: '$id MC');
      expect(of(QuestionType.fillInBlank).length, _fib, reason: '$id boşluk');
      expect(of(QuestionType.wordOrdering).length, _wo, reason: '$id cümle');
    }
    expect(
      playable.where((q) => q.id.startsWith('dersler4_2026_10_25_')).length,
      76,
    );
  });

  test(
    'yeni dersler kendi kategorisinde eski derslerden sonra gelir',
    () async {
      final repository = freshMockRepository();
      for (final category in {'grammar', 'time'}) {
        final lessons = await repository.loadLessonsByCategory(category);
        final ids = lessons.map((l) => l.id).toList();
        final mine = [
          for (final entry in _lessons.entries)
            if (entry.value == category) entry.key,
        ];
        final older = ids.where((id) => !mine.contains(id)).toList();
        expect(older, isNotEmpty, reason: category);
        for (final id in mine) {
          expect(ids, contains(id));
          expect(ids.indexOf(id), greaterThan(ids.indexOf(older.last)));
          expect(
            await repository.loadLessonSlides(id),
            hasLength(5),
            reason: id,
          );
        }
        final orders = lessons.map((l) => l.order).toList();
        expect(orders, [...orders]..sort(), reason: category);
        expect(orders.toSet().length, orders.length, reason: category);
      }
    },
  );

  test('her yeni ders sunucu slugına bağlı, sözlük kaynağı ve kısa testi '
      'taşır', () async {
    final repository = freshMockRepository();
    for (final id in _lessons.keys) {
      final slug = _slugs[id]!;
      expect(LearningLessonAliases.bankIdsFor(slug), [id], reason: slug);
      expect(LearningLessonAliases.completionSlugFor(id), slug, reason: id);
      expect(LearnerLexicon.sources.containsKey(id), isTrue, reason: id);
      expect(
        LearnerLexicon.entriesForSource(id).length,
        greaterThanOrEqualTo(8),
        reason: '$id sözlük',
      );
      for (final key in [id, slug]) {
        final questions = await repository.loadLearningQuizQuestions(
          category: 'Ziman',
          learningLessonId: key,
          limit: 5,
        );
        expect(questions, hasLength(5), reason: key);
        expect(
          questions.every((q) => q.metadata?.learningLessonId == id),
          isTrue,
          reason: '$key kısa testi başka dersin sorusunu karıştırıyor',
        );
      }
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
          q.id.startsWith('dersler4_2026_10_25_') &&
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

  test('aynı derste boşluk doldurma cümlesi ve cümle kurma hedefi tekrar '
      'etmez', () {
    for (final id in _lessons.keys) {
      Iterable<QuizQuestion> of(QuestionType type) => playable.where(
        (q) => q.type == type && q.metadata?.learningLessonId == id,
      );
      final fibPrompts = of(QuestionType.fillInBlank).map((q) => q.prompt);
      expect(fibPrompts.toSet().length, _fib, reason: '$id aynı cümle');
      final woAnswers = of(
        QuestionType.wordOrdering,
      ).map((q) => q.correctAnswer);
      expect(woAnswers.toSet().length, _wo, reason: '$id aynı dizilim');
    }
  });
}
