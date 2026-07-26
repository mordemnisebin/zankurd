import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Kategori gizleme mekanizmasının bekçisi.
///
/// Teknolojî 2026-07-19'da gizlenmişti: 23 sorusu Türkçe meta/test içeriği
/// taşıyordu ve karar "içerik yayına hazır olana dek" diye yazılmıştı.
/// 2026-07-26'da koşul karşılandı — kusurlu sorular ayıklandı (23 → 12),
/// kalanlar denetlendi, 28 yeni soru yazıldı — ve kategori açıldı.
///
/// Testler artık kategoriyi değil **mekanizmayı** doğruluyor: liste boş da
/// olsa gizleme çalışmalı, çünkü bir sonraki hazır olmayan kategori için
/// yine gerekecek.
void main() {
  test('şu an gizli kategori yok', () {
    expect(hiddenCategoryIds, isEmpty);
    expect(isCategoryVisible('Teknolojî'), isTrue);
    expect(isCategoryVisible('Ziman'), isTrue);
  });

  test('visibleCategories sırayı korur', () {
    final input = ['Ziman', 'Teknolojî', 'Çand'];
    expect(visibleCategories(input), input);
  });

  test('gizleme mekanizması hâlâ çalışıyor', () {
    // Liste boşaldı ama mekanizma durmalı: bir sonraki hazır olmayan
    // kategori için yine gerekecek. `isPlayable` gizli kategoriyi her
    // akışta eler — quiz seçimi, günlük soru ve banka sızıntıları tek
    // noktadan kapanır.
    const policy = QuestionContentPolicy();
    const question = QuizQuestion(
      id: 'ziman-1',
      category: 'Ziman',
      prompt: 'pîr ne demektir?',
      answers: ['Yaşlı', 'Genç', 'Hızlı', 'Yavaş'],
      correctAnswer: 'Yaşlı',
      explanation: 'Pîr yaşlı demektir.',
    );

    expect(policy.isPlayable(question), isTrue);
    expect(isCategoryVisible(question.category), isTrue);

    // Meta/şema soruları artık kategori gizlemeyle değil, banka bekçisiyle
    // eleniyor (bkz. `question_distractor_quality_test`: "soru bankası
    // kendi şemasını sormaz"). Yapısal doğrulama bunları görmez.
    const meta = QuizQuestion(
      id: 'tech-meta-1',
      category: 'Teknolojî',
      prompt: 'Kaynak sütunu CSVde ne işe yarar?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'meta',
    );
    expect(policy.validate(meta), isEmpty);
  });
}
