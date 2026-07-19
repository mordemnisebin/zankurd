import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Teknolojî kategorisi içerik yayına hazır olana dek uygulama içinde gizli
/// (2026-07-19 canlı denetim P1: kategori Türkçe meta/test soruları içeriyor).
void main() {
  test('Teknolojî gizli kategori listesinde', () {
    expect(hiddenCategoryIds, contains('Teknolojî'));
    expect(isCategoryVisible('Teknolojî'), isFalse);
    expect(isCategoryVisible('Ziman'), isTrue);
  });

  test('visibleCategories gizli kategoriyi düşürür, sırayı korur', () {
    final input = ['Ziman', 'Teknolojî', 'Çand'];
    expect(visibleCategories(input), ['Ziman', 'Çand']);
  });

  test('içerik politikası gizli kategori sorularını oynanabilir saymaz', () {
    const policy = QuestionContentPolicy();
    const hidden = QuizQuestion(
      id: 'tech-meta-1',
      category: 'Teknolojî',
      prompt: 'Kaynak sütunu CSVde ne işe yarar?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'meta',
    );
    const visible = QuizQuestion(
      id: 'ziman-1',
      category: 'Ziman',
      prompt: 'pîr ne demektir?',
      answers: ['Yaşlı', 'Genç', 'Hızlı', 'Yavaş'],
      correctAnswer: 'Yaşlı',
      explanation: 'Pîr yaşlı demektir.',
    );
    expect(policy.isPlayable(hidden), isFalse);
    expect(policy.isPlayable(visible), isTrue);
  });
}
