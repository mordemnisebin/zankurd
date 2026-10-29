import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Şık konumu sözleşmesi — oyuncunun GÖRDÜĞÜ sıra ile sunucuya giden
/// anahtar (2026-10-29 Opus–Astra kapışması, U2).
///
/// ## İddia ve çürütülmesi
///
/// Kapışma "şıklar hiç karıştırılmıyor, doğru cevap %30 A şıkkında" dedi.
/// Ölçülen konum JSON'daki DEPOLANAN sıraydı. Oyuncu `displayAnswers`ı görür:
/// kimlikten türeyen sabit bir kaydırma (sayısal şıklarda yönlü sıralama).
/// Görünen konum bütün bankada ve kategori başına zaten dengeli
/// (`question_bank_test`, `answer_position_category_balance_test`).
///
/// ## Bu bekçinin kapattığı boşluk
///
/// Denge testleri yalnız Kurmancî diziye bakıyordu; dil değişince görünen
/// sıranın aynı kalması yalnız dört genişletme ailesinde ölçülüyordu. Burada
/// BÜTÜN oynanabilir 4 şıklı sorularda sözleşme sabitlenir:
/// 1. Türkçe yansıtılmış soru, doğru cevabı Kurmancî ile AYNI görünen
///    konumda gösterir (dil değişimi sırayı bozmaz).
/// 2. Görünen her şıkkın anahtarı (`optionKeyForAnswer`) DEPOLANAN
///    indekstir — sunucu (`submit_answer`, `answer_async_duel`,
///    `answer_tournament_question`) bu anahtarı bekler; görünüm kaydırması
///    sözleşmeye sızmaz.
/// 3. Aynı soru her çağrıda aynı sırayı verir (yeniden açma, iki istemci).
void main() {
  final questions = [
    for (final q in MockZanKurdRepository().playableQuestions)
      if (q.type == QuestionType.multipleChoice &&
          q.answers.length == 4 &&
          q.answers.contains(q.correctAnswer))
        q,
  ];

  test('bekçi kör değil', () {
    expect(questions.length, greaterThan(1000));
  });

  test('Türkçe ve Kurmancî doğru cevabı aynı görünen konumda gösterir', () {
    final offenders = <String>[];
    for (final q in questions) {
      final ku = q.displayAnswers.indexOf(q.correctAnswer);
      final tr = q.localized(isKu: false);
      final trIndex = tr.displayAnswers.indexOf(tr.correctAnswer);
      if (ku != trIndex) offenders.add('${q.id}: ku=$ku tr=$trIndex');
    }
    expect(offenders, isEmpty, reason: offenders.take(20).join('\n'));
  });

  test('görünen şıkkın sunucu anahtarı depolanan indekstir', () {
    const keys = ['A', 'B', 'C', 'D'];
    for (final q in questions) {
      for (final shown in q.displayAnswers) {
        final stored = q.answers.indexOf(shown);
        expect(q.optionKeyForAnswer(shown), keys[stored], reason: q.id);
        expect(q.answerForOptionKey(keys[stored]), shown, reason: q.id);
      }
    }
  });

  test('görünen sıra kararlı (yeniden açma / iki istemci)', () {
    for (final q in questions) {
      final again = QuizQuestion.fromJson(q.toJson());
      expect(again.displayAnswers, q.displayAnswers, reason: q.id);
    }
  });

  test('görünen konum dengeli, depolanan konum dengesiz olabilir', () {
    final shown = List<int>.filled(4, 0);
    for (final q in questions) {
      shown[q.displayAnswers.indexOf(q.correctAnswer)]++;
    }
    final total = shown.reduce((a, b) => a + b);
    for (final count in shown) {
      expect(
        (100 * count / total - 25).abs(),
        lessThan(3),
        reason: 'görünen dağılım $shown',
      );
    }
  });
}
