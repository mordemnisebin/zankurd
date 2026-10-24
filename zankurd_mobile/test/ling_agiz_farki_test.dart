import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

/// TestFlight 37 (2026-10-25): "___ min diêşe." sorusu yalnız "Linga"yı
/// kabul ediyordu; sahibi "Lingê" yazdı ve yanlış sayıldı. Standart
/// Kurmancîde `ling` eril sayılır ("lingê min"), birçok ağızda dişil
/// ("linga min"); jüri (Gemini 3.8 Flash + Grok 4.7) ikisinin de kabulünü
/// önerdi. Ders, sözlük ve ses "Linga" ile kaldığı için ana cevap odur.
void main() {
  test('ling sorusu Linga ve Lingê cevaplarını kabul eder', () {
    final q = QuestionBankLoader.instance.allQuestions.firstWhere(
      (x) => x.id == 'dersler2_2026_10_08_0032',
    );
    expect(q.correctAnswer, 'Linga');
    expect(q.acceptsAnswer('Linga'), isTrue);
    expect(q.acceptsAnswer('Lingê'), isTrue);
    expect(q.acceptsAnswer('lingê'), isTrue);
    expect(q.acceptsAnswer('Ling'), isFalse);
    for (final isKu in [true, false]) {
      expect(q.localized(isKu: isKu).acceptsAnswer('Lingê'), isTrue);
      expect(
        q.localized(isKu: isKu, learning: true).acceptsAnswer('Lingê'),
        isTrue,
      );
    }
  });
}
