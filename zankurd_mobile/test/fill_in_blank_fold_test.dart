import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/utils/free_text_answer_matcher.dart';

/// Boşluk doldurmada inceltmesiz yazım (2026-10-15).
///
/// ## Kusur
///
/// Cevabı `ç ş ê î û` taşıyan 29 boşluk doldurma sorusunun ASCII varyantı
/// tanımlı değildi: İngilizce klavyeyle `cay` yazan `çay`ı biliyor olsa da
/// yanlış sayılıyordu. Öte yandan elle girilen varyantlar bazen başka bir
/// gerçek sözcüktü: `şêr` (aslan) için `şer` (savaş), `dê` için `de`, `tê`
/// için `te` kabul ediliyordu.
///
/// ## Niçin sessiz kaldı
///
/// Klavye testi yalnız `î ê û` için varyantın VARLIĞINA bakıyordu, varyantın
/// ne olduğuna değil; `ç`/`ş` hiç sınanmıyordu. Sorular iyi görünüyordu,
/// yalnız belli bir klavyeyle oynayanlar sessizce kaybediyordu.
///
/// ## Bekçi
///
/// Birebir yazım doğru; inceltmesi eksik yazım da doğru AMA ekran doğru
/// yazımı gösterir (`matchAnswer` → folded); gerçek başka sözcük
/// (`kFoldDistinctWords`) katlanmaz; bankadaki her yeni inceltme çakışması
/// o listede olmak zorundadır.
QuizQuestion _fill(String answer, {String prompt = 'Ev ___ e.'}) =>
    QuizQuestion(
      id: 'fill-$answer',
      category: 'Ziman',
      prompt: prompt,
      answers: [answer],
      correctAnswer: answer,
      explanation: '',
      type: QuestionType.fillInBlank,
    );

String _fold(String value) => foldFreeTextDiacritics(value.toLowerCase());

void main() {
  test('çay: birebir exact, cay ve CAY folded', () {
    final q = _fill('çay');
    expect(q.matchAnswer('çay'), FreeTextMatch.exact);
    expect(q.matchAnswer('ÇAY'), FreeTextMatch.exact);
    expect(q.matchAnswer('cay'), FreeTextMatch.folded);
    expect(q.matchAnswer('CAY'), FreeTextMatch.folded);
    expect(q.acceptsAnswer('cay'), isTrue);
    expect(q.matchAnswer('çaz'), FreeTextMatch.none);
  });

  test('başka gerçek sözcük katlanmaz', () {
    expect(_fill('şêr').matchAnswer('şer'), FreeTextMatch.none);
    expect(_fill('şêr').matchAnswer('ser'), FreeTextMatch.none);
    expect(_fill('dê').matchAnswer('de'), FreeTextMatch.none);
    expect(_fill('tê').matchAnswer('te'), FreeTextMatch.none);
    // Ters yön: cevap `te` iken yazılan `tê` de başka bir sözcüktür.
    expect(_fill('te').matchAnswer('tê'), FreeTextMatch.none);
    expect(_fill('çil').matchAnswer('cil'), FreeTextMatch.none);
  });

  test('sorunun başka şıkkının katlanmışıyla çakışan yazım reddedilir', () {
    const q = QuizQuestion(
      id: 'fill-rival',
      category: 'Ziman',
      prompt: 'Ev ___ e.',
      answers: ['kêr', 'ker'],
      correctAnswer: 'kêr',
      explanation: '',
      type: QuestionType.fillInBlank,
    );
    expect(q.matchAnswer('ker'), FreeTextMatch.none);
    expect(q.matchAnswer('kêr'), FreeTextMatch.exact);
  });

  test('harfin yazımını soran soruda katlama yok', () {
    final q = _fill('sûd', prompt: 'Peyva «û» ünlüsüyle rast binivîse.');
    expect(q.matchAnswer('sud'), FreeTextMatch.none);
    expect(q.matchAnswer('sûd'), FreeTextMatch.exact);
  });

  group('banka', () {
    late List<QuizQuestion> blanks;
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await QuestionBankLoader.instance.load();
      blanks = QuestionBankLoader.instance.allQuestions
          .where((q) => q.type == QuestionType.fillInBlank)
          .toList();
    });

    test('inceltmesi tümden düşen yazım her soruda kabul edilir', () {
      final offenders = <String>[];
      for (final q in blanks) {
        final bare = _fold(q.correctAnswer);
        if (kFoldDistinctWords.contains(bare)) continue;
        // Harfin yazımını soran sorular (sûd, lêv, çak) katlamayı reddeder.
        final text = '${q.prompt} ${q.promptTr ?? ''}';
        if ('çşêîû'
            .split('')
            .any(
              (l) =>
                  q.correctAnswer.contains(l) &&
                  (text.contains('«$l»') || text.contains('"$l"')),
            )) {
          expect(q.acceptsAnswer(bare), isFalse, reason: q.id);
          continue;
        }
        if (!q.acceptsAnswer(bare))
          offenders.add('${q.id}: «$bare» reddedildi');
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('editörün alternatifi başka bir gerçek sözcük değildir', () {
      final offenders = <String>[];
      for (final q in blanks) {
        for (final accepted in q.acceptedAnswers) {
          if (kFoldDistinctWords.contains(accepted.toLowerCase()) &&
              accepted.toLowerCase() != q.correctAnswer.toLowerCase()) {
            offenders.add('${q.id}: «$accepted» ayrı bir sözcük');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('bankadaki her inceltme çakışması kFoldDistinctWords içinde', () {
      final vocabulary = <String>{};
      for (final entry in LearnerLexicon.entries) {
        for (final text in [entry.termKu, ...entry.forms]) {
          vocabulary.addAll(
            text.toLowerCase().split(RegExp(r'[^\p{L}]+', unicode: true)),
          );
        }
      }
      for (final q in blanks) {
        vocabulary.addAll(q.correctAnswer.toLowerCase().split(' '));
      }
      vocabulary.remove('');
      final missing = <String>{};
      for (final q in blanks) {
        final answer = q.correctAnswer.toLowerCase();
        if (answer.contains(' ')) continue;
        for (final word in vocabulary) {
          if (word != answer &&
              _fold(word) == _fold(answer) &&
              !kFoldDistinctWords.contains(word)) {
            missing.add('$word (${q.id}: $answer)');
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'Bu sözcükler cevaplardan yalnız inceltmeyle ayrılıyor; '
            'kFoldDistinctWords içine eklenmeli:\n${missing.join("\n")}',
      );
    });
  });
}
