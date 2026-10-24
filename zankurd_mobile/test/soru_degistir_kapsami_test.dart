import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/wildcard_replacement.dart';

/// "Soru değiştir" jokeri kapsamı korur (2026-10-15).
///
/// ## Kusur
///
/// Joker aynı kategorideki herhangi bir kullanılmamış soruyu çekiyordu:
/// 30 jeton ödeyip bir cümle kurma sorusunun yerine tarih ya da başka bir
/// dersin sorusunu alabiliyordunuz; ders testi dersin dışına çıkıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Joker testleri "jeton düştü, soru değişti" diye bakıyordu; yeni sorunun
/// eskisiyle aynı türden/kapsamdan olduğunu soran yoktu.
///
/// ## Bekçi
///
/// Yedek aynı tür ve aynı ders/alt konudan gelir, turdaki soru olmaz; hiç
/// aday yoksa eski davranışa (aynı kategori) düşülür.
QuizQuestion _q(
  String id, {
  String category = 'Ziman',
  QuestionType type = QuestionType.multipleChoice,
  String prompt = 'Pirsa',
  String correct = 'a',
  String? lesson,
  int difficulty = 1,
}) => QuizQuestion(
  id: id,
  category: category,
  prompt: prompt,
  answers: [correct, 'b', 'c', 'd'],
  correctAnswer: correct,
  explanation: '',
  type: type,
  difficulty: difficulty,
  metadata: lesson == null ? null : QuestionMetadata(learningLessonId: lesson),
);

bool _all(QuizQuestion q) => true;

void main() {
  test('aynı dersin aynı türünden gelir', () {
    final current = _q('cur', lesson: 'L1', type: QuestionType.wordOrdering);
    final pool = [
      current,
      _q('mc-same-lesson', lesson: 'L1'),
      _q('wo-other-lesson', lesson: 'L2', type: QuestionType.wordOrdering),
      _q('wo-same-lesson', lesson: 'L1', type: QuestionType.wordOrdering),
    ];
    final ids = wildcardReplacementCandidates(
      current: current,
      pool: pool,
      usedIds: {'cur'},
      usable: _all,
    ).map((q) => q.id);
    expect(ids, ['wo-same-lesson']);
  });

  test('derssizse aynı alt konudan gelir', () {
    final current = _q('cur', category: 'Dîrok', prompt: 'Paytexta Medan?');
    final pool = [
      current,
      _q('kevn', category: 'Dîrok', prompt: 'Keyê Medan kî bû?'),
      _q(
        'nujen',
        category: 'Dîrok',
        prompt: 'Komara Tirkiyê kengî hat avakirin?',
      ),
    ];
    final ids = wildcardReplacementCandidates(
      current: current,
      pool: pool,
      usedIds: {'cur'},
      usable: _all,
    ).map((q) => q.id);
    expect(ids, ['kevn']);
  });

  test('turdaki soru yedek olmaz', () {
    final current = _q('cur', lesson: 'L1');
    final pool = [current, _q('used', lesson: 'L1'), _q('free', lesson: 'L1')];
    final ids = wildcardReplacementCandidates(
      current: current,
      pool: pool,
      usedIds: {'cur', 'used'},
      usable: _all,
    ).map((q) => q.id);
    expect(ids, ['free']);
  });

  test('önce aynı zorluk, yoksa kapsam içinde başka zorluk', () {
    final current = _q('cur', lesson: 'L1', difficulty: 2);
    final pool = [
      current,
      _q('hard', lesson: 'L1', difficulty: 4),
      _q('same', lesson: 'L1', difficulty: 2),
    ];
    expect(
      wildcardReplacementCandidates(
        current: current,
        pool: pool,
        usedIds: {'cur'},
        usable: _all,
      ).map((q) => q.id),
      ['same'],
    );
    expect(
      wildcardReplacementCandidates(
        current: current,
        pool: [
          current,
          _q('hard', lesson: 'L1', difficulty: 4),
        ],
        usedIds: {'cur'},
        usable: _all,
      ).map((q) => q.id),
      ['hard'],
    );
  });

  test('kapsamda aday yoksa eski davranışa (aynı kategori) düşer', () {
    final current = _q('cur', lesson: 'L1', type: QuestionType.wordOrdering);
    final pool = [current, _q('other', lesson: 'L9')];
    final ids = wildcardReplacementCandidates(
      current: current,
      pool: pool,
      usedIds: {'cur'},
      usable: _all,
    ).map((q) => q.id);
    expect(ids, ['other']);
  });

  test('kategori dışı soru hiçbir basamakta gelmez', () {
    final current = _q('cur');
    final ids = wildcardReplacementCandidates(
      current: current,
      pool: [
        current,
        _q('x', category: 'Dîrok'),
      ],
      usedIds: {'cur'},
      usable: _all,
    );
    expect(ids, isEmpty);
  });
}
