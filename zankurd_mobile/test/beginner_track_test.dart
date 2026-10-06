import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

import 'support/widget_test_helpers.dart';

/// Başlangıç yolu (2026-10-06).
///
/// ## Kusur
///
/// Sıfırdan başlayan test kullanıcıları iki şeyden yakındı: soru azdı ve
/// uygulama Kürtçeyi ZATEN bilenlere göre kurulmuştu. Alfabe, aile, kendini
/// tanıtma dersi yoktu; "boşluk doldur" bankası 20, "kelimeleri sürükleyip
/// cümle kur" bankası 8 soruydu ve ikisi de derse bağlı değildi
/// (`learningLessonId` yok): dersin kısa testi yalnız şık sorusu gösteriyordu,
/// sözlük de sorulardaki sözcüklerin çoğunu içermiyordu — bilmediği sözcüğü
/// aratan öğrenen sonuç bulamıyordu.
///
/// ## Niçin sessiz kalıyordu
///
/// Hiçbir şey "yeni başlayan bu içeriğe ULAŞIYOR mu" ve "sözlük sorudaki
/// sözcükleri kapsıyor mu" diye ölçmüyordu; sayılar yalnız bankanın
/// büyüklüğünü sabitliyordu. Arama da aksan duyarlıydı: Türkçe klavyeyle
/// yazılan `cay` `Çay`ı bulmuyordu.
///
/// ## Bekçi
///
/// Dört yeni ders (alfabe, selamlaşma II, kendini tanıtma, aile) derse bağlı
/// en az 8 çoktan seçmeli, 10 boşluk doldurma ve 8 cümle kurma taşır;
/// bankalar toplamda >= 60 / >= 45 oynanabilir üretim sorusu verir; dersin
/// kısa testi üretim sorusu içerir; sözlük iki yönde ders ve sorularla
/// örtüşür; arama aksansızdır.
const _newLessons = ['alphabet_1', 'greetings_2', 'intro_1', 'family_1'];
const _policy = QuestionContentPolicy();

String _fold(String value) => LearnerLexicon.foldForSearch(value);

/// Kurmancî metni sözcüklerine ayırır (noktalama ve tırnak atılır).
List<String> _tokens(String text) => RegExp(
  r"[^\s,.?!:;()/\x27\x22“”«»–—]+",
).allMatches(_fold(text)).map((m) => m.group(0)!).toList();

void main() {
  late List<QuizQuestion> playable;
  late MockZanKurdRepository repository;

  setUpAll(() {
    playable = QuestionBankLoader.instance.allQuestions
        .where(_policy.isPlayable)
        .toList();
  });
  setUp(() => repository = freshMockRepository());

  test('her yeni ders derse bağlı >= 8 çoktan seçmeli, >= 10 boşluk '
      'doldurma, >= 8 cümle kurma taşır', () {
    for (final id in _newLessons) {
      Iterable<QuizQuestion> of(QuestionType type) => playable.where(
        (q) => q.type == type && q.metadata?.learningLessonId == id,
      );
      expect(
        of(QuestionType.multipleChoice).length,
        greaterThanOrEqualTo(8),
        reason: '$id çoktan seçmeli',
      );
      expect(
        of(QuestionType.fillInBlank).length,
        greaterThanOrEqualTo(10),
        reason: '$id boşluk doldurma',
      );
      expect(
        of(QuestionType.wordOrdering).length,
        greaterThanOrEqualTo(8),
        reason: '$id cümle kurma',
      );
    }
  });

  test('oynanabilir boşluk doldurma >= 60 ve cümle kurma >= 45', () {
    int count(QuestionType type) =>
        playable.where((q) => q.type == type).length;
    expect(count(QuestionType.fillInBlank), greaterThanOrEqualTo(60));
    expect(count(QuestionType.wordOrdering), greaterThanOrEqualTo(45));
  });

  test('yeni dersler öğrenme yolunda başlangıç sırasıyla durur', () async {
    final lessons = await repository.loadLessonsByCategory('everyday');
    final ids = lessons.map((l) => l.id).toList();
    expect(ids.first, 'alphabet_1', reason: 'alfabe yolun başı');
    for (final id in _newLessons) {
      expect(ids, contains(id));
    }
    // Zor derslerden (everyday_3: günlük pratik ifadeler) ÖNCE gelirler.
    for (final id in _newLessons) {
      expect(ids.indexOf(id), lessThan(ids.indexOf('everyday_3')), reason: id);
    }
    expect(ids.indexOf('greetings_2'), greaterThan(ids.indexOf('everyday_1')));
    expect(ids.indexOf('intro_1'), greaterThan(ids.indexOf('everyday_2')));
    final orders = lessons.map((l) => l.order).toList();
    expect(orders, [...orders]..sort(), reason: 'order sütunu sıralı');
    expect(orders.toSet().length, orders.length);
  });

  test('dersin kısa testi cümle kurma ve boşluk doldurma içerir', () async {
    for (final id in [..._newLessons, 'everyday_1', 'food_1', 'grammar_1']) {
      final questions = await repository.loadLearningQuizQuestions(
        category: 'Ziman',
        learningLessonId: id,
        limit: 5,
      );
      expect(questions, hasLength(5), reason: id);
      expect(
        questions.any((q) => q.type == QuestionType.wordOrdering),
        isTrue,
        reason: '$id kısa testinde cümle kurma yok',
      );
      expect(
        questions.any((q) => q.type == QuestionType.fillInBlank),
        isTrue,
        reason: '$id kısa testinde boşluk doldurma yok',
      );
      // Isınma: ilk iki soru tanıma sorusu.
      expect(
        questions
            .take(2)
            .every(
              (q) =>
                  q.type != QuestionType.fillInBlank &&
                  q.type != QuestionType.wordOrdering,
            ),
        isTrue,
        reason: id,
      );
    }
  });

  test('Ziman Destpêk turu yeni başlayana cümle kurma getirir', () async {
    var withOrdering = 0;
    for (var i = 0; i < 12; i++) {
      final questions = await repository.loadLevelQuestions(
        category: 'Ziman',
        difficultyMin: 1,
        difficultyMax: 2,
        levelNumber: 1,
        limit: 10,
      );
      expect(questions.first.type, isNot(QuestionType.wordOrdering));
      expect(questions[1].type, isNot(QuestionType.wordOrdering));
      if (questions.any((q) => q.type == QuestionType.wordOrdering)) {
        withOrdering++;
      }
    }
    expect(withOrdering, 12, reason: 'her Destpêk turunda cümle kurma olmalı');
  });

  test('günlük ders cümle kurma içerir', () async {
    final questions = await repository.loadDailyQuestions(limit: 10);
    expect(questions.any((q) => q.type == QuestionType.wordOrdering), isTrue);
  });

  group('sözlük', () {
    late Set<String> dictionaryTokens;
    late String corpus;

    setUpAll(() async {
      dictionaryTokens = {
        for (final entry in LearnerLexicon.entries) ...[
          ..._tokens(entry.termKu),
          for (final form in entry.forms) ..._tokens(form),
        ],
      };
      final repo = freshMockRepository();
      final slideText = StringBuffer();
      for (final category in const [
        'everyday',
        'grammar',
        'culture',
        'food',
        'animals',
        'geography',
        'emotions',
        'time',
      ]) {
        for (final Lesson lesson in await repo.loadLessonsByCategory(
          category,
        )) {
          for (final slide in await repo.loadLessonSlides(lesson.id)) {
            slideText.writeln(slide.contentKu);
          }
        }
      }
      final tagged = QuestionBankLoader.instance.allQuestions.where(
        (q) => q.metadata?.learningLessonId != null,
      );
      final questionText = StringBuffer();
      for (final q in tagged) {
        questionText
          ..writeln(q.prompt)
          ..writeln(q.answers.join(' '))
          ..writeln(q.correctAnswer)
          ..writeln(q.explanationKu ?? '');
      }
      final seed = File(
        'supabase/2026-07-06_lesson_seed.sql',
      ).readAsStringSync();
      corpus = ' ${_tokens('$slideText $questionText $seed').join(' ')} ';
    });

    test('derslerde öğretilen her çift sözlükte vardır', () async {
      final terms = LearnerLexicon.entries.map((e) => _fold(e.termKu)).toSet();
      final missing = <String>[];
      for (final category in const [
        'everyday',
        'grammar',
        'culture',
        'food',
        'animals',
        'geography',
        'emotions',
        'time',
      ]) {
        for (final lesson in await repository.loadLessonsByCategory(category)) {
          for (final slide in await repository.loadLessonSlides(lesson.id)) {
            for (final line in slide.contentKu.split('\n')) {
              final match = RegExp(r'^• (.+?): (.+)$').firstMatch(line);
              if (match == null) continue;
              if (!terms.contains(_fold(match.group(1)!))) {
                missing.add('${lesson.id}: ${match.group(1)}');
              }
            }
          }
        }
      }
      expect(missing, isEmpty, reason: 'sözlükte yok: $missing');
    });

    test('başlangıç sorularındaki her Kurmancî sözcük sözlükte vardır', () {
      final missing = <String>{};
      final beginner = playable.where(
        (q) =>
            q.id.startsWith('baslangic_2026_10_06_') &&
            q.type != QuestionType.multipleChoice,
      );
      for (final q in beginner) {
        final sentence = q.type == QuestionType.wordOrdering
            ? q.correctAnswer
            : RegExp(r'"([^"]*___[^"]*)"')
                  .firstMatch(q.prompt)!
                  .group(1)!
                  .replaceAll('___', q.correctAnswer);
        for (final token in _tokens(sentence)) {
          if (RegExp(r'^\d+$').hasMatch(token)) continue;
          if (!dictionaryTokens.contains(token)) missing.add(token);
        }
      }
      expect(missing, isEmpty, reason: 'sözlükte olmayan sözcük: $missing');
    });

    test('çeviri sorularının sorduğu terimler sözlükte vardır', () {
      // "Dûr" bi Tirkî çi ye? -> tırnak içi terim; "…" bi Kurmancî çi ye? ->
      // doğru cevap terimdir.
      final missing = <String>{};
      final beginner = playable.where(
        (q) =>
            q.metadata?.learningLessonId != null &&
            q.type == QuestionType.multipleChoice &&
            (q.id.startsWith('ders_2026_10_0') ||
                q.id.startsWith('baslangic_2026_10_06_')),
      );
      for (final q in beginner) {
        String? term;
        if (q.prompt.contains('bi Tirkî çi ye') ||
            q.prompt.contains('bi tirkî çi ye')) {
          term = RegExp(r'^"([^"]+)"').firstMatch(q.prompt)?.group(1);
        } else if (q.prompt.contains('bi Kurmancî çi ye') ||
            q.prompt.contains('bi kurmancî çi')) {
          term = q.correctAnswer;
        }
        if (term == null) continue;
        for (final token in _tokens(term)) {
          if (!dictionaryTokens.contains(token)) {
            missing.add('$token (${q.id})');
          }
        }
      }
      expect(missing, isEmpty, reason: 'sözlükte olmayan terim: $missing');
    });

    test('her sözlük kaydı uygulamada (ders ya da soru) kullanılır', () {
      final unused = <String>[];
      for (final entry in LearnerLexicon.entries) {
        final variants = [
          ...entry.termKu.split(' / '),
          ...entry.forms,
        ].map((v) => _tokens(v).join(' ')).where((v) => v.isNotEmpty);
        if (!variants.any((v) => corpus.contains(' $v '))) {
          unused.add('${entry.id} (${entry.termKu})');
        }
      }
      expect(unused, isEmpty, reason: 'hiçbir ders/soruda geçmiyor: $unused');
    });

    test('arama aksan duyarsızdır (iki dilde)', () {
      List<String> ids(String q) =>
          LearnerLexicon.search(q).map((e) => e.termKu).toList();
      expect(ids('cay'), contains('Çay'));
      expect(ids('CAY'), contains('Çay'));
      expect(ids('sev'), contains('Şev'));
      expect(ids('kopek'), contains('Kûçik / Seg'), reason: 'köpek anlamı');
      expect(ids('evar'), contains('Êvar'));
      expect(ids('evar').first, 'Êvar', reason: 'tam eşleşme önce gelir');
      expect(ids('Çay'), contains('Çay'));
      // Biçimler aranır: çekimli sözcük madde başını bulur.
      expect(ids('dizanim'), contains('Zanîn'));
      expect(ids('male'), contains('Mal'));
      // x ve q katlanmaz: "xal" ile "kal" aynı şey değildir.
      expect(ids('xal'), contains('Xal'));
      expect(ids('qelem'), contains('Qelem'));
      expect(ids('kelem'), isNot(contains('Qelem')));
    });
  });
}
