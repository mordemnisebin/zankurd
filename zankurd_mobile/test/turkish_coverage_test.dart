import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Türkçe kapsamı YÜKLEYİCİNİN çıktısı üzerinden ölçülür.
///
/// ## Kusur
///
/// 2026-08-09'da "Türkçe kapsamı %100" diye rapor edildi. Ölçüm yanlıştı:
/// yalnız `assets/data/*.json` bankaları sayılmıştı ve
/// `lib/src/data/curated_question_bank.dart` — Dart sabiti olarak tutulan
/// 45 soruluk üçüncü banka — ölçüme hiç girmemişti. O 45 sorunun hiçbirinde
/// `promptTr` yoktu.
///
/// Kusur ertesi gün simülatörde ortaya çıktı: Türkçe arayüzde açılan ilk
/// soru Kurmancî geldi.
///
/// Bu, bu deponun kendi belgelediği hatanın aynısı — bkz.
/// `all_banks_quality_test.dart`'ın başlığı: bir kaynak listesi elle
/// çoğaltıldığında kopyalar ayrışır ve ölçüm, baktığı yerde kusur olmadığı
/// için "temiz" der.
///
/// Bu yüzden ölçüm burada elle yazılmış bir listeden değil, uygulamanın
/// GERÇEKTEN yüklediği kümeden yapılır: `QuestionBankLoader` curated bankayı
/// da JSON bankalarını da birleştirir. Yeni bir kaynak eklendiğinde bu bekçi
/// onu kendiliğinden görür.
void main() {
  const policy = QuestionContentPolicy();

  late List<QuizQuestion> playable;

  setUpAll(() {
    playable = QuestionBankLoader.instance.allQuestions
        .where(policy.isPlayable)
        .toList();
  });

  /// Türkçe oturumda soru TAM gösterilebiliyor mu?
  ///
  /// Cümle kurma ayrı tutulur: orada `answers` şık listesi değil Kurmancî
  /// kelime havuzudur ve alıştırmanın kendisidir; çevrilmesi soruyu yok
  /// eder. Orada ölçüt yalnız soru metnidir.
  bool fullyTurkish(QuizQuestion q) {
    if (q.type == QuestionType.wordOrdering) {
      return (q.promptTr ?? '').trim().isNotEmpty;
    }
    return q.hasTurkishTranslation;
  }

  test('oynanabilir her soru Türkçe oturumda tam gösterilebiliyor', () {
    final missing = playable.where((q) => !fullyTurkish(q)).toList();

    expect(
      missing,
      isEmpty,
      reason:
          'Türkçe seçen oyuncu bu ${missing.length} soruyu Kurmancî görür. '
          'Model bunu sessizce yapar (`answersFor` tutarsız çeviride '
          'Kurmancî\'ye düşer), yani hiçbir hata görünmez:\n'
          '${missing.take(15).map((q) => '${q.id} (${q.category})').join("\n")}',
    );
  });

  test('curated Dart bankası ölçüme dahil', () {
    // Kusurun kendisi buydu: ölçüm bu bankayı görmüyordu. Bekçi, bankanın
    // yüklenen kümede GERÇEKTEN bulunduğunu doğrular; bulunmazsa üstteki
    // test boş bir kümede koşup sessizce geçerdi.
    final curated = playable.where((q) => q.id.startsWith('curated_')).toList();
    // 45 kaydın tamamı oynanabilir: 2026-09-02'de kuyruktaki 7 bozuk
    // Kurmancî kayıt yeniden yazıldı. Sayı düşerse banka yüklenen kümede
    // görünmüyor demektir; artarsa sessizce yeni curated id girmiştir.
    expect(
      curated.length,
      45,
      reason:
          'Curated bankadan oynanabilir soru sayısı değişti. Düştüyse banka '
          'yüklenen kümede görünmüyor ve kapsam ölçümü onu atlıyor demektir; '
          'arttıysa `needsReview` kayıtlardan biri denetlenmeden açılmıştır.',
    );
    expect(curated.every(fullyTurkish), isTrue);
  });

  test('her kategoride Türkçe oynanabilir soru bir turu dolduruyor', () {
    // Kapsam toplamda %100 olsa bile tek bir kategoride toplanabilirdi.
    const roundSize = 10;
    final byCategory = <String, int>{};
    for (final q in playable.where(fullyTurkish)) {
      byCategory[q.category] = (byCategory[q.category] ?? 0) + 1;
    }
    final thin = byCategory.entries
        .where((e) => e.value < roundSize)
        .map((e) => '${e.key}: ${e.value}')
        .toList();
    expect(thin, isEmpty, reason: 'Türkçe turu dolmayan kategori: $thin');
    expect(byCategory.length, 10);
  });
}
