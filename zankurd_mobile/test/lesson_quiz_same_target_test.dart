import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';
import 'support/widget_test_helpers.dart';

/// Ders mini testinde aynı cümle/terim iki soru türüyle sorulmaz.
///
/// ## Kusur
///
/// 2026-10-07 simülatör QA'sında bir mini test "Navê min Rojîn e" cümlesini
/// önce cümle kurma, sonra "'Navê min Rojîn e' Türkçesi nedir?" olarak
/// sordu: oyuncu cümleyi kurduktan hemen sonra çevirisini ekranda
/// okuyordu — ikinci soru ilkinin cevabıydı.
///
/// Sessizdi çünkü çeşitlilik süzgeci yalnız tırnaklı terim ya da KISA cevaba
/// bakıyordu (dört sözcüklü cümle ikisine de takılmaz) ve cümle kurma ile
/// şıklı sorular `_selectLessonMix` içinde AYRI havuzlardan seçilip sonra
/// birleştirildiği için birbirlerini hiç görmüyordu.
QuizQuestion _q(
  String id,
  QuestionType type,
  String prompt,
  String correct, {
  List<String>? answers,
}) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: prompt,
  answers: answers ?? [correct, 'x1', 'x2', 'x3'],
  correctAnswer: correct,
  explanation: '',
  type: type,
);

void main() {
  test('cümle kurma ile o cümleyi alıntılayan şıklı soru tekrar sayılır', () {
    final ordering = _q(
      'a',
      QuestionType.wordOrdering,
      'Hevokê rêz bike',
      'Navê min Rojîn e',
      answers: ['Navê', 'min', 'Rojîn', 'e'],
    );
    final mc = _q(
      'b',
      QuestionType.multipleChoice,
      '"Navê min Rojîn e" bi tirkî çi ye?',
      'Benim adım Rojîn',
    );
    final other = _q(
      'c',
      QuestionType.multipleChoice,
      '"Silav" bi tirkî çi ye?',
      'Merhaba',
    );
    expect(QuestionSetPolicy.sharesTargetText(ordering, mc), isTrue);
    expect(QuestionSetPolicy.sharesTargetText(ordering, other), isFalse);
    final picked = QuestionSetPolicy.diverseWithoutLeaks([
      ordering,
      mc,
      other,
    ], limit: 2);
    expect(picked.map((q) => q.id), ['a', 'c']);
  });

  test('doğru/yanlış ve hüküm sözcükleri hedef sayılmaz', () {
    final tf1 = _q(
      't1',
      QuestionType.trueFalse,
      'Roj tê? Rast e an şaş e?',
      'Rast',
    );
    final tf2 = _q(
      't2',
      QuestionType.trueFalse,
      'Av şil e? Rast e an şaş e?',
      'Rast',
    );
    expect(QuestionSetPolicy.sharesTargetText(tf1, tf2), isFalse);
  });

  test('hiçbir ders mini testi aynı cümle/terimi iki kez sormaz', () async {
    final repository = freshMockRepository();
    final lessons = [
      for (final category in const [
        'everyday',
        'grammar',
        'culture',
        'food',
        'animals',
        'emotions',
        'time',
        'alphabet',
        'greetings',
        'family',
        'intro',
        'numbers',
        'body',
      ])
        ...await repository.loadLessonsByCategory(category),
    ];
    expect(lessons, isNotEmpty);
    final seen = <String>{};
    final violations = <String>[];
    for (final lesson in lessons) {
      if (!seen.add(lesson.slug)) continue;
      final category = quizCategoryForLesson(lesson.category);
      for (var run = 0; run < 12; run++) {
        final questions = await repository.loadLearningQuizQuestions(
          category: category,
          learningLessonId: lesson.slug,
          limit: 5,
        );
        for (var i = 0; i < questions.length; i++) {
          for (var j = i + 1; j < questions.length; j++) {
            if (QuestionSetPolicy.sharesTargetText(
              questions[i],
              questions[j],
            )) {
              violations.add(
                '${lesson.slug}: ${questions[i].id} / ${questions[j].id}',
              );
            }
          }
        }
      }
    }
    expect(violations.toSet(), isEmpty);
  });
}
