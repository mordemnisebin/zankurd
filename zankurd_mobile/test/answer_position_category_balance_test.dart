import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Doğru cevabın GÖRÜNEN konumu KATEGORİ başına dengeli mi, doğru/yanlış
/// şıkları standart mı (2026-10-02 denge denetimi).
///
/// ## Kusur
///
/// `question_bank_test` yalnız BÜTÜN bankanın dört konum arasındaki
/// yayılımına bakıyordu (≤ 1). Toplam dengeliyken tek tek kategoriler
/// kayabilir; eksiklikler birbirini götürür. Denge denetimi kategori başına
/// çarpıklık raporladı. Rapor DEPOLANAN konumu ölçmüştü (Siyaset A %55);
/// oyuncunun GÖRDÜĞÜ konum `displayAnswers`ın kimlikten türeyen
/// kaydırmasından sonrakidir ve çoğu kategoride zaten dağılmıştı — ama
/// OYNANABİLİR sorularda Edebiyat B %30 / D %19, Siyaset A %20 / C %29,
/// Dîrok A %21 / B %28 çıkıyordu. Hiçbir bekçi bunu görmüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Küresel yayılım dengeliyken kategori sapması test edilmiyordu ve araç
/// (`tool/rebalance_answer_positions.py`) tek havuz üzerinde çalışıyordu.
/// Ayrıca küçük kategoriler için emekli/gizli sorular dengeyi "dengeli"
/// gösterip oynanabilir kümeyi çarpık bırakabiliyordu: bekçi oynanabilir
/// kümeyi ölçer.
///
/// ## Doğru/yanlış şıkları
///
/// 448 soru "Rast"/"Şaş" (Türkçe "Doğru"/"Yanlış") kullanıyordu; dördü
/// ters sırada ("Şaş, Rast"), ikisi "Rast e"/"Şaş e" idi. Doğru/yanlış
/// sorusunda şıkların konumu `displayAnswers`ta döndürülmez: ters sıra,
/// oyuncunun "ilk şık doğru" alışkanlığını bozan sessiz bir tutarsızlıktır.
void main() {
  test('gerçek banka yüklü (bekçi kör kalmasın)', () {
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
  });

  test('oynanabilir 4 şıklı sorularda her kategoride her konum %25 ± 5', () {
    final repository = MockZanKurdRepository();
    final byCategory = <String, List<int>>{};
    for (final q in repository.playableQuestions) {
      if (q.type == QuestionType.trueFalse ||
          q.answers.length != 4 ||
          !q.answers.contains(q.correctAnswer)) {
        continue;
      }
      final counts = byCategory.putIfAbsent(q.category, () => [0, 0, 0, 0]);
      counts[q.displayAnswers.indexOf(q.correctAnswer)]++;
    }
    expect(byCategory.length, greaterThan(8));

    final failures = <String>[];
    byCategory.forEach((category, counts) {
      final total = counts.reduce((a, b) => a + b);
      // Çok küçük kategorilerde yüzde anlamsız (bir soru = onlarca puan).
      if (total < 40) return;
      for (var position = 0; position < 4; position++) {
        final percent = 100 * counts[position] / total;
        if ((percent - 25).abs() > 5) {
          failures.add(
            '$category: ${'ABCD'[position]} %${percent.toStringAsFixed(1)} '
            '($counts, n=$total)',
          );
        }
      }
    });
    expect(
      failures,
      isEmpty,
      reason:
          '${failures.join('\n')}\nDüzeltmek için: flutter test '
          'tool/parity/dump_local_bank_test.dart ve ardından '
          'python3 tool/rebalance_answer_positions.py --playable '
          '.tmp/parity/local_bank.json',
    );
  });

  test(
    'metin şıklarının maç dağılımı sessizdi; eski bekçi yalnız bankayı ölçüyordu',
    () {
      final byCategory = <String, List<int>>{};
      final questions = MockZanKurdRepository().playableQuestions.where(
        (q) =>
            q.type == QuestionType.multipleChoice &&
            q.answers.length == 4 &&
            q.answers.contains(q.correctAnswer) &&
            // Sayısal şıklar sözleşme gereği yönlü sıralanır; bir sayının
            // sıralı dört konumu da ziyaret etmesini beklemek yanlıştır.
            // Eski tüm-banka kategori bekçisi yukarıda aynen korunur.
            !q.answers.every(
              (a) => num.tryParse(a.trim().replaceAll('.', '')) != null,
            ),
      );
      for (var match = 0; match < 100; match++) {
        for (final source in questions) {
          final q = source.forRound('category-match-$match');
          final counts = byCategory.putIfAbsent(q.category, () => [0, 0, 0, 0]);
          counts[q.displayAnswers.indexOf(q.correctAnswer)]++;
        }
      }
      expect(byCategory.length, greaterThan(8));
      for (final entry in byCategory.entries) {
        final total = entry.value.reduce((a, b) => a + b);
        for (final count in entry.value) {
          expect(
            100 * count / total,
            inInclusiveRange(22, 28),
            reason: '${entry.key}: ${entry.value}',
          );
        }
      }
    },
  );

  test('doğru/yanlış şıkları hep Rast, Şaş (Doğru, Yanlış) sırasında', () {
    final bad = <String>[];
    for (final q in QuestionBankLoader.instance.allQuestions) {
      if (q.type != QuestionType.trueFalse) continue;
      if (q.answers.join('|') != 'Rast|Şaş') {
        bad.add('${q.id}: ${q.answers}');
      }
      final tr = q.answersTr;
      if (tr != null && tr.join('|') != 'Doğru|Yanlış') {
        bad.add('${q.id} (TR): $tr');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
