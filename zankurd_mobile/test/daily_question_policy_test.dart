import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  test('günlük quiz yalnız oynanabilir soruları döndürür', () async {
    const playable = QuizQuestion(
      id: 'approved-visible',
      category: 'Ziman',
      prompt: 'Pirsê derbasdar?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya derbasdar.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.approved),
    );
    const needsReview = QuizQuestion(
      id: 'needs-review',
      category: 'Ziman',
      prompt: 'Pirsê li benda kontrolê?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya li benda kontrolê.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.needsReview),
    );
    const rejected = QuizQuestion(
      id: 'rejected',
      category: 'Ziman',
      prompt: 'Pirsa hatiye redkirin?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya hatiye redkirin.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.rejected),
    );
    // Bu kayıt eskiden "gizli kategori elenir" durumunu sınıyordu (Sînema).
    // Sînema 2026-07-30'da açılınca ve gizleme listesi boşalınca o dal
    // sınanamaz oldu — `hiddenCategoryIds` `const`, teste sahte id
    // enjekte edilemiyor. Kayıt silinmedi, yönü çevrildi: artık *açılan
    // bir kategorinin günlük akışa gerçekten ulaştığını* doğruluyor.
    // Kilit açmak yalnız listeden bir satır silmek değildir; günlük soru,
    // quiz seçimi ve banka akışlarının hepsinden geçmesi gerekir ve bu
    // testler o zincirin günlük halkasıdır.
    const yeniAcilanKategori = QuizQuestion(
      id: 'approved-sinema',
      category: 'Sînema',
      prompt: 'Pirsa ji kategoriya nû vebûyî?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya kategoriya nû vebûyî.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.approved),
    );

    QuestionBankLoader.instance.setQuestionsForTest([
      playable,
      needsReview,
      rejected,
      yeniAcilanKategori,
    ]);

    final questions = await MockZanKurdRepository().loadDailyQuestions(
      limit: 10,
    );

    expect(questions.map((question) => question.id).toSet(), {
      'approved-visible',
      'approved-sinema',
    });
  });
}
