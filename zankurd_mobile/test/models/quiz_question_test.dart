import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  group('QuizQuestion', () {
    test('hasImage returns true when imageUrl is not null', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'This is correct',
        imageUrl: 'assets/image.jpg',
      );

      expect(question.hasImage, true);
    });

    test('hasImage returns false when imageUrl is null', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'This is correct',
      );

      expect(question.hasImage, false);
    });

    // Bu iki test bir zamanlar `typeLabel`i ölçüyordu — yalnız Türkçe
    // döndüren, üretimde hiç çağrılmayan bir ikizdi ve testler onu canlı
    // tutuyordu. Ölçülmesi gereken, ekranda gerçekten görünen
    // `typeLabelLocalized`dir (2026-07-31 denetimi).
    test('tip rozeti çoktan seçmeli için iki dilde doğru', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'This is correct',
      );

      expect(question.typeLabelLocalized(false), 'Şıklı');
      expect(question.typeLabelLocalized(true), 'Hilbijartin');
    });

    test('tip rozeti doğru/yanlış için iki dilde doğru', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        explanation: 'This is correct',
        type: QuestionType.trueFalse,
      );

      expect(question.typeLabelLocalized(false), 'Doğru/Yanlış');
      expect(question.typeLabelLocalized(true), 'Rast/Xelet');
    });

    test('displayAnswers moves stored first answer for multiple choice', () {
      const question = QuizQuestion(
        id: 'q_shuffle',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Correct', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
        correctAnswer: 'Correct',
        explanation: 'This is correct',
      );

      expect(question.displayAnswers.toSet(), question.answers.toSet());
      expect(question.displayAnswers.first, isNot(question.answers.first));
    });

    test(
      'optionKeyForAnswer keeps backend option keys tied to stored answers',
      () {
        const question = QuizQuestion(
          id: 'q_shuffle',
          category: 'Ziman',
          prompt: 'Test question?',
          answers: ['Correct', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
          correctAnswer: 'Correct',
          explanation: 'This is correct',
        );

        expect(question.optionKeyForAnswer('Correct'), 'A');
        expect(question.optionKeyForAnswer('Wrong 1'), 'B');
        expect(question.optionKeyForAnswer('Wrong 2'), 'C');
        expect(question.optionKeyForAnswer('Wrong 3'), 'D');
      },
    );

    // Cümle kurmada `answers` bir şık listesi değil kelime havuzudur ve
    // gönderilen cevap havuzdaki tek bir kelimeyle değil `correctAnswer`
    // (birleştirilmiş cümle) ile karşılaştırılmalı. Eskiden bu metot
    // `answers.indexOf(answer)` çalıştırıyordu — cümle asla havuzdaki tek
    // bir kelimeye eşit olmadığı için sonuç hep -1'e, dolayısıyla cevap hep
    // boş dizeye düşüyordu; sonraki karşılaştırma bu yüzden hep başarısız
    // oluyordu (bkz. `MockZanKurdRepository.submitAnswer` testi altta).
    test('optionKeyForAnswer cümle kurmada ham cümleyi olduğu gibi taşır', () {
      const question = QuizQuestion(
        id: 'q_word_order',
        category: 'Ziman',
        prompt: 'Cümleyi kur',
        answers: ['im', 'xwendekar', 'Ez'],
        correctAnswer: 'Ez xwendekar im',
        explanation: 'Doğru cümle',
        type: QuestionType.wordOrdering,
      );

      expect(question.optionKeyForAnswer('Ez xwendekar im'), 'Ez xwendekar im');
      expect(question.optionKeyForAnswer('im Ez xwendekar'), 'im Ez xwendekar');
    });

    test('true false display order stays stable', () {
      const question = QuizQuestion(
        id: 'q_tf',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        explanation: 'This is correct',
        type: QuestionType.trueFalse,
      );

      expect(question.displayAnswers, ['Rast', 'Şaş']);
    });

    test(
      'getLocalizedExplanation returns localized explanations correctly',
      () {
        const question = QuizQuestion(
          id: 'q_explanation_test',
          category: 'Ziman',
          prompt: 'Test?',
          answers: ['A', 'B'],
          correctAnswer: 'A',
          explanation: 'Default explanation',
          explanationKu: 'Kurdish explanation',
          explanationTr: 'Turkish explanation',
        );

        expect(question.getLocalizedExplanation(true), 'Kurdish explanation');
        expect(question.getLocalizedExplanation(false), 'Turkish explanation');
      },
    );

    test(
      'getLocalizedExplanation falls back to base explanation or local translation function',
      () {
        const question = QuizQuestion(
          id: 'q_explanation_fallback',
          category: 'Ziman',
          prompt: 'Test?',
          answers: ['A', 'B'],
          correctAnswer: 'A',
          explanation: '"av" kelimesi "su" anlamına gelir.',
        );

        // Kurdish mode uses local translation mapping (explanationToKu) on the base explanation
        expect(
          question.getLocalizedExplanation(true),
          'Peyva «av» tê wateya «su».',
        );
        expect(
          question.getLocalizedExplanation(false),
          '"av" kelimesi "su" anlamına gelir.',
        );
      },
    );
  });

  group('MockZanKurdRepository question bank', () {
    test(
      'ships a broad offline question bank instead of the tiny demo set',
      () {
        final repository = MockZanKurdRepository();
        final uniquePrompts = repository.questions
            .map((question) => question.prompt)
            .toSet();
        final visualQuestions = repository.questions
            .where((question) => question.hasImage)
            .toList();

        expect(repository.questions.length, greaterThanOrEqualTo(200));
        expect(uniquePrompts.length, greaterThanOrEqualTo(180));
        expect(visualQuestions.length, greaterThanOrEqualTo(40));
      },
    );

    test('loadQuestions rotates results between calls', () async {
      final repository = MockZanKurdRepository();

      final first = await repository.loadQuestions(limit: 10);
      final second = await repository.loadQuestions(limit: 10);

      expect(
        first.map((question) => question.id),
        isNot(second.map((q) => q.id)),
      );
    });

    // ## Kusur
    //
    // `submitAnswer` her soru tipi için `answers.indexOf(correctAnswer)`u
    // A-D anahtarına çevirip gelen cevapla karşılaştırıyordu. Cümle
    // kurmada `answers` kelime havuzu, `correctAnswer` ise birleştirilmiş
    // cümledir — `indexOf` bu cümleyi tek bir kelime arasında asla bulamaz,
    // sonuç hep -1'e, eşleme hep 'D'ye düşer. `optionKeyForAnswer` da
    // (yukarıdaki eski davranışıyla) gelen cevabı boş dizeye indirgediği
    // için karşılaştırma hep başarısızdı: cümle kurma soruları yerel
    // (offline/mock) puanlama hattında HER ZAMAN yanlış işaretleniyordu,
    // kullanıcı doğru cümleyi kursa bile (2026-08-14 denetimi).
    //
    // ## Düzeltme
    //
    // `submitAnswer` artık cümle kurma tipini ayrı ele alır: doğruluk,
    // gönderilen cevabın `correctAnswer`la (kenar boşlukları hariç)
    // birebir eşleşmesiyle ölçülür.
    group('submitAnswer cümle kurma sorularını doğru puanlar', () {
      const question = QuizQuestion(
        id: 'q_word_order',
        category: 'Ziman',
        prompt: 'Cümleyi kur',
        answers: ['im', 'xwendekar', 'Ez'],
        correctAnswer: 'Ez xwendekar im',
        explanation: 'Doğru cümle',
        type: QuestionType.wordOrdering,
      );

      test('doğru sırayla kurulan cümle doğru sayılır', () async {
        final repository = MockZanKurdRepository();
        final room = repository.createRoom();

        final result = await repository.submitAnswer(
          room: room,
          question: question,
          selectedOptionOptionKey: question.optionKeyForAnswer(
            'Ez xwendekar im',
          ),
          responseMs: 2000,
        );

        expect(result['is_correct'], isTrue);
      });

      test('yanlış sırayla kurulan cümle yanlış sayılır', () async {
        final repository = MockZanKurdRepository();
        final room = repository.createRoom();

        final result = await repository.submitAnswer(
          room: room,
          question: question,
          selectedOptionOptionKey: question.optionKeyForAnswer(
            'im Ez xwendekar',
          ),
          responseMs: 2000,
        );

        expect(result['is_correct'], isFalse);
      });
    });
  });
}
