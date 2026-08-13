import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// OYNANABİLİR her sorunun iki dilde de açıklaması olduğunun bekçisi.
///
/// ## Kusur
///
/// Açıklamalar bu üründe tur sonunda toplu gösterilir; oyuncunun bir turdan
/// öğrendiği şey odur. Açıklaması olmayan bir soru o listede boş bir satır
/// bırakır — oyuncu neyi yanlış bildiğini öğrenmeden geçer.
///
/// ## Ölçüm (2026-08-12)
///
/// İlk sayım 116 dedi ve YANLIŞTI: ham `explanation` alanına bakıyordu.
/// Oyuncuya gösterilen şey `getLocalizedExplanation`, o da önce
/// `explanationKu`/`explanationTr` alanlarına bakar. `source_first`
/// bankasının 101 sorusunda o alanlar zaten doluydu.
///
/// Doğru ölçü accessor üzerinden alınınca sayı 16'ya indi. Bunların 15'i
/// topluluk bankasından geliyor ve `ContentQualityPolicy` tarafından zaten
/// eleniyor (`rejected`/`needsReview`), yani oyuncuya hiç ulaşmıyor.
/// Oyuncuya ulaşan tek soru `offline_0895` idi ve açıklaması
/// "Doğru yanıt: tembûr." gibi bir şablondu — `isTemplateExplanation` onu
/// eliyor, dolayısıyla ekranda hiçbir şey görünmüyordu. O soruya gerçek bir
/// açıklama yazıldı.
///
/// ## Bu bekçi niçin ELEME'yi de kapsıyor
///
/// Kalan 15 soru bugün zararsız çünkü kapının arkasında. Ama bir gün
/// onaylanırlarsa açıklamasız hâlde oyuncuya ulaşırlar ve bunu hiçbir şey
/// durdurmaz. Bekçi bu yüzden "oynanabilir" kümesini ölçer: bir soru
/// onaylandığı ANDA açıklaması olmak zorunda.
///
/// Kalan 15'e açıklama YAZILMADI. İçerikleri doğrulanamayan olgu iddiaları
/// taşıyor (şehit ve sanatçı adları); hafızadan açıklama yazmak, projenin
/// "sahte kaynak üretme" kuralını çiğnerdi. Onaylanacaklarsa açıklamaları
/// kaynağıyla birlikte yazılmalı.
void main() {
  const policy = QuestionContentPolicy();

  late List<QuizQuestion> playable;

  setUpAll(() {
    playable = QuestionBankLoader.instance.allQuestions
        .where(policy.isPlayable)
        .toList();
  });

  test('oynanabilir her soruda Kurmancî açıklama var', () {
    final offenders = playable
        .where((q) => q.getLocalizedExplanation(true).trim().isEmpty)
        .map((q) => q.id)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu sorular oyuncuya ulaşıyor ama tur sonundaki açıklama listesinde '
          'boş satır bırakıyor. Şablon açıklama ("Doğru yanıt: X") sayılmaz; '
          'elenir:\n${offenders.take(20).join(", ")}',
    );
  });

  test('oynanabilir her soruda Türkçe açıklama var', () {
    final offenders = playable
        .where((q) => q.getLocalizedExplanation(false).trim().isEmpty)
        .map((q) => q.id)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'Türkçe oynayan oyuncu bu sorularda hiçbir şey öğrenmiyor:\n'
          '${offenders.take(20).join(", ")}',
    );
  });

  test('elenen sorulardaki açıklama borcu ölçülüyor', () {
    // Borç gizlenmiyor, sayılıyor. Bu sayı DÜŞMELİ: bir soru onaylanmadan
    // önce açıklaması yazılırsa buradan düşer, onaylanınca da üstteki iki
    // testten geçer. Sayı ARTARSA yeni bir açıklamasız kayıt eklenmiş
    // demektir ve o kayıt er geç onaya girer.
    const knownDebt = 15;
    final blocked = QuestionBankLoader.instance.allQuestions
        .where((q) => !policy.isPlayable(q))
        .where((q) => q.getLocalizedExplanation(true).trim().isEmpty)
        .map((q) => q.id)
        .toList();
    expect(
      blocked.length,
      lessThanOrEqualTo(knownDebt),
      reason:
          'Açıklamasız ve elenmiş soru sayısı arttı (${blocked.length} > '
          '$knownDebt). Bunlar bugün oyuncuya ulaşmıyor ama onaylandıkları '
          'anda ulaşır:\n${blocked.take(20).join(", ")}',
    );
  });
}
