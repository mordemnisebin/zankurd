import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

/// Konu çeşitliliği denetimi ve alt konu planı hızı (2026-10-15).
///
/// ## Kusur
///
/// `repeatsSubject` çift başına hedef metinleri, konu anahtarını ve prompt
/// belirteçlerini yeniden çıkarıyordu; `normalize` her karakter için yeni bir
/// düzenli ifade derliyordu. "Rêziman" alt konu planı (425 soru) takas
/// döngüsünde yüzbinlerce çift dener: test koşucusunda 10 dakikayı aşıyor,
/// ekran turunun "38b seviyeler (alt kategori)" karesini zaman aşımına
/// uğratıyordu (kusur içerik büyüyünce ortaya çıktı).
///
/// ## Niçin sessiz kaldı
///
/// Sonuç doğruydu, yalnız yavaştı; planı kuran testler küçük havuzlarla ya da
/// planı hiç kurmadan çalışıyordu.
///
/// ## Bekçi
///
/// Önbellekli `repeatsSubject`, açık üç kuralın birleşimiyle birebir aynı
/// sonucu verir; Rêziman planı birkaç saniyede kurulur.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await QuestionBankLoader.instance.load();
  });

  bool reference(QuizQuestion a, QuizQuestion b) {
    if (QuestionSetPolicy.sharesTargetText(a, b)) return true;
    final keyA = QuestionSetPolicy.subjectKey(a);
    if (keyA != null && keyA == QuestionSetPolicy.subjectKey(b)) return true;
    return QuestionSetPolicy.promptSimilarity(a.prompt, b.prompt) >=
        QuestionSetPolicy.similarPromptThreshold;
  }

  test('repeatsSubject açık kuralların birleşimiyle aynı sonucu verir', () {
    final questions = QuestionBankLoader.instance.allQuestions
        .where((q) => q.category == 'Ziman')
        .take(300)
        .toList();
    var checked = 0;
    for (var i = 0; i < questions.length; i += 3) {
      for (var j = i; j < questions.length; j += 7) {
        expect(
          QuestionSetPolicy.repeatsSubject(questions[i], questions[j]),
          reference(questions[i], questions[j]),
          reason: '${questions[i].id} / ${questions[j].id}',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(1000));
  });

  test(
    'Rêziman alt konu planı makul sürede kurulur',
    () {
      final stopwatch = Stopwatch()..start();
      final levels = MockZanKurdRepository().levelsForCategory(
        'Ziman',
        subCategory: 'reziman',
      );
      expect(levels, isNotEmpty);
      expect(stopwatch.elapsed, lessThan(const Duration(minutes: 1)));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
