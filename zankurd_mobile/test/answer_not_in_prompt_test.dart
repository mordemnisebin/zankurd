import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Doğru cevap, aynı dildeki soru metninde ayrı bir sözcük/öbek olarak geçmez.
///
/// ## Kusur
///
/// Çeviri sorularının Türkçe varyantı ters yazılmıştı (2026-10-07 simülatör
/// QA'sı): `promptTr` `"Çok teşekkürler" Kurmancîsi nedir?` diyor, ama
/// `answersTr` ile `correctAnswerTr` de Türkçeydi ve doğru cevap
/// "Çok teşekkürler" idi — yani cevap sorunun içinde yazıyordu. 40 soruda
/// (başlangıç yolu ve iki ders bankası) Türkçe oynayan herkes soruyu
/// okumadan çözüyordu. Kurmancî varyant doğruydu (şıklar Kurmancî).
///
/// Sessizdi çünkü her varyantı kendi içinde denetleyen tek şey, cevabın
/// şıklar arasında bulunmasıydı (bulunuyordu); `promptTr` ile cevabı yan
/// yana koyan hiçbir bekçi yoktu ve sızıntı süzgeci (`leaksBetween`) yalnız
/// SORULAR ARASINDAKİ sızıntıya bakar.
///
/// Eşleşme sözcük sınırıyla yapılır: `heft` cevabı `hefteyekê` sözcüğünün
/// içinde geçtiği için ihlal sayılmaz.
String _fold(String value) => value
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('i̇', 'i')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _contains(String answer, String prompt) {
  final a = _fold(answer);
  final p = ' ${_fold(prompt)} ';
  return a.isNotEmpty && p.contains(' $a ');
}

/// Eski, KASITLI olarak bırakılmış ihlaller: cevap tek ortak sözcük ve soru
/// metni bilgiyi zaten yarı açıkça veriyor (Roma/İpek). Bunlar çeviri
/// tersliği değil, içerik zayıflığı: banka yeniden yazılırken düzeltilecek.
/// Liste ELLE büyütülemez; yeni ihlal doğrudan başarısızlıktır.
///
/// Üç grup daha KASITLI ve haksız sızıntı değil: `ds_cand_0285` (cevap
/// "Mem" eser adının parçası), `ex28_rastnivisin_006` (cevap tek harf "ı"
/// ve soru o harfi tarif ediyor), `edit_ziman_0031` (cevap "bi-" ön eki,
/// soruda "bi kîjan" olarak ortak sözcük). Boşluk doldurma soruları hiç
/// denetlenmez: parantez içi Türkçe karşılığı verilen cümlede boşluğun
/// karşılığı çeviri olarak soru metninde görünür; bu, tasarımın kendisi.
const _legacy = <String>{
  'ds_cand_0285|ku',
  'ds_cand_0285|tr',
  'ex28_rastnivisin_006|ku',
  'ex28_rastnivisin_006|tr',
  'edit_ziman_0031|ku',
  'ds_dirok_0175|tr',
  'ds_dirok_0277|tr',
  'ds_dirok_0291|tr',
};

void main() {
  test('doğru cevap, aynı dildeki soru metninin içinde geçmez', () {
    const policy = QuestionContentPolicy();
    final violations = <String>{};
    for (final q in QuestionBankLoader.instance.allQuestions) {
      if (!policy.isPlayable(q)) continue;
      if (q.type == QuestionType.trueFalse) continue;
      if (q.type == QuestionType.fillInBlank) continue;
      for (final (lang, isKu) in [('ku', true), ('tr', false)]) {
        final prompt = q.promptFor(isKu: isKu);
        final answer = q.correctAnswerFor(isKu: isKu);
        if (_contains(answer, prompt)) violations.add('${q.id}|$lang');
      }
    }
    final fresh = violations.difference(_legacy);
    expect(
      fresh,
      isEmpty,
      reason:
          'Cevabı soru metninde yazan soru(lar): $fresh. Çeviri sorusunda '
          'promptTr kaynak terimi alıntılıyorsa answersTr/correctAnswerTr '
          'hedef dilde olmalı.',
    );
    final stale = _legacy.difference(violations);
    expect(stale, isEmpty, reason: 'Düzelmiş ama listede kalmış: $stale');
  });
}
