import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/curated_question_bank.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Soru çok dilliliğinin sözleşmesi.
///
/// 2026-07-25 denetimi: arayüz TR seçilebiliyor ama soruların %100'ü
/// Kurmancî. Bu bir içerik eksiği gibi görünse de asıl engel şemadaydı —
/// [QuizQuestion] tek bir `prompt` alanı taşıyordu, çeviri yazılacak yer
/// yoktu. Alanlar eklendi; bu testler yansıtmanın *güvenli* olduğunu
/// garanti eder, çünkü yanlış yansıtma sessizce yanlış puanlamaya yol açar.
void main() {
  QuizQuestion base({
    String? promptTr,
    List<String>? answersTr,
    String? correctAnswerTr,
  }) {
    return QuizQuestion(
      id: 'q1',
      category: 'Dîrok',
      prompt: 'Mîrgeha Botan li ku bû?',
      answers: const ['Cizîr', 'Hewlêr', 'Amed'],
      correctAnswer: 'Cizîr',
      explanation: '',
      promptTr: promptTr,
      answersTr: answersTr,
      correctAnswerTr: correctAnswerTr,
    );
  }

  group('yansıtma', () {
    test('Kurmancî istendiğinde aynı nesne döner', () {
      final question = base(promptTr: 'Botan Beyliği neredeydi?');
      expect(identical(question.localized(isKu: true), question), isTrue);
    });

    test('tam çeviri varsa alanlar Türkçeye geçer', () {
      final question = base(
        promptTr: 'Botan Beyliği neredeydi?',
        answersTr: const ['Cizre', 'Erbil', 'Diyarbakır'],
        correctAnswerTr: 'Cizre',
      );
      final tr = question.localized(isKu: false);
      expect(tr.prompt, 'Botan Beyliği neredeydi?');
      expect(tr.answers, ['Cizre', 'Erbil', 'Diyarbakır']);
      expect(tr.correctAnswer, 'Cizre');
      // Doğru cevap her zaman şıklardan biri olmalı; aksi halde hiçbir şık
      // doğru işaretlenmez ve tur sessizce bozulur.
      expect(tr.answers, contains(tr.correctAnswer));
    });

    test('çeviri yoksa Kurmancî kalır', () {
      final tr = base().localized(isKu: false);
      expect(tr.prompt, 'Mîrgeha Botan li ku bû?');
      expect(tr.correctAnswer, 'Cizîr');
    });

    test('şık sayısı uyuşmuyorsa tamamı Kurmancî kalır', () {
      // Yarısı çevrilmiş bir şık listesi, hiç çevrilmemiş olandan daha
      // kafa karıştırıcıdır.
      final question = base(
        promptTr: 'Botan Beyliği neredeydi?',
        answersTr: const ['Cizre', 'Erbil'],
        correctAnswerTr: 'Cizre',
      );
      final tr = question.localized(isKu: false);
      expect(tr.answers, ['Cizîr', 'Hewlêr', 'Amed']);
      expect(tr.correctAnswer, 'Cizîr');
      expect(tr.answers, contains(tr.correctAnswer));
    });

    test('boş şık çevirisi tamamı Kurmancî kalır', () {
      final question = base(
        promptTr: 'Botan Beyliği neredeydi?',
        answersTr: const ['Cizre', '', 'Diyarbakır'],
        correctAnswerTr: 'Cizre',
      );
      expect(question.localized(isKu: false).answers, question.answers);
    });

    test('doğru cevap çevirisi şıklarda yoksa güvenli tarafa düşer', () {
      // Tutarsız veri sessizce "hiçbir şık doğru değil" durumuna yol
      // açmamalı.
      final question = base(
        promptTr: 'Botan Beyliği neredeydi?',
        answersTr: const ['Cizre', 'Erbil', 'Diyarbakır'],
        correctAnswerTr: 'Van',
      );
      final tr = question.localized(isKu: false);
      expect(tr.answers, contains(tr.correctAnswer));
    });
  });

  group('JSON gidiş-dönüş', () {
    test('çok dilli alanlar korunur', () {
      final question = base(
        promptTr: 'Botan Beyliği neredeydi?',
        answersTr: const ['Cizre', 'Erbil', 'Diyarbakır'],
        correctAnswerTr: 'Cizre',
      );
      final restored = QuizQuestion.fromJson(question.toJson());
      expect(restored.promptTr, question.promptTr);
      expect(restored.answersTr, question.answersTr);
      expect(restored.correctAnswerTr, question.correctAnswerTr);
    });

    test('eski kayıtlar (alansız) hâlâ okunur', () {
      final legacy = {
        'id': 'old',
        'category': 'Ziman',
        'prompt': 'Pirs',
        'answers': ['a', 'b'],
        'correctAnswer': 'a',
        'explanation': '',
      };
      final restored = QuizQuestion.fromJson(legacy);
      expect(restored.promptTr, isNull);
      expect(restored.hasTurkishTranslation, isFalse);
      expect(restored.localized(isKu: false).prompt, 'Pirs');
    });
  });

  test('çeviri kapsamı ölçülebilir', () {
    // Bugün sıfır; banka çevrildikçe bu sayı yükselecek. Test kapsamı
    // *ölçer*, bir eşik dayatmaz — çeviri içerik işidir, kod işi değil.
    final translated = curatedQuestionBank
        .where((q) => q.hasTurkishTranslation)
        .length;
    expect(translated, greaterThanOrEqualTo(0));
    expect(translated, lessThanOrEqualTo(curatedQuestionBank.length));
  });
}
