import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
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
  test('yayın tabanının altındaki Sînema gizli', () {
    expect(hiddenCategoryIds, {'Sînema'});
    expect(isCategoryVisible('Sînema'), isFalse);
    expect(isCategoryVisible('Teknolojî'), isTrue);
    expect(isCategoryVisible('Ziman'), isTrue);
  });

  test('görünür her kategori bir turu taşıyacak kadar dolu', () {
    // Bir düello 10 soruluk. 21 soruluk bir kategoride havuz iki turda
    // tükeniyor ve sorular tekrar etmeye başlıyor — kategori "açık"
    // görünüyor ama oynanmıyor. Sînema tam olarak bu durumdaydı
    // (2026-07-26: 21 → 45).
    //
    // Taban 40: dört ayrı tur demek. Teknolojî de kapatılmak yerine bu
    // sayıya kadar doldurulmuştu; ölçüt oradan alındı. Bu bir mandal —
    // yeni bir kategori açmak, onu doldurmadan mümkün olmasın.
    const floor = 40;
    final counts = <String, int>{};
    for (final source in [
      'assets/data/offline_questions.json',
      'assets/data/community_questions.json',
      'assets/data/editorial_questions.json',
    ]) {
      final file = File(source);
      if (!file.existsSync()) continue;
      for (final raw in jsonDecode(file.readAsStringSync()) as List) {
        final category = (raw as Map<String, dynamic>)['category'] as String;
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }

    final thin = counts.entries
        .where((e) => isCategoryVisible(e.key) && e.value < floor)
        .map((e) => '${e.key}: ${e.value}')
        .toList();

    expect(
      thin,
      isEmpty,
      reason: 'Görünür ama tek tur bile taşımayan kategori: ${thin.join(", ")}',
    );
  });

  test('visibleCategories sırayı korur', () {
    final input = ['Ziman', 'Teknolojî', 'Çand'];
    expect(visibleCategories([...input, 'Sînema']), input);
  });

  test(
    'deponun senkron ve asenkron kategori girişleri gizliyi sızdırmaz',
    () async {
      final repository = MockZanKurdRepository();

      expect(repository.categories, isNot(contains('Sînema')));
      expect(await repository.loadCategories(), isNot(contains('Sînema')));
    },
  );

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

    const rejected = QuizQuestion(
      id: 'rejected-1',
      category: 'Ziman',
      prompt: 'Pirs?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Ravekirina bersivê.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.rejected),
    );
    expect(policy.isPlayable(rejected), isFalse);

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
