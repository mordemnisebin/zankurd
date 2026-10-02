/// Türkçe şık sırasının Kurmancî şık sırasıyla hizasının bekçisi.
///
/// ## Kusur
///
/// `QuizQuestion._hasConsistentTurkishAnswers` yalnız doğru cevabın Türkçe
/// şık kümesinde VAR OLUP OLMADIĞINA bakar; `answersTr[i]`nin `answers[i]`
/// ile aynı şıkkın çevirisi olup olmadığına, yani SIRAYA hiç bakmaz. Bu
/// yüzden 14 Edebiyat sorusunda Türkçe şıklar başka sorulardan sızmış hâlde
/// (ör. "Latin alfabesinin yayılması", "karşılıklı konuşma") banka içinde
/// sessizce durdu: doğru cevabın metni Türkçe dizide bir YERDE bulunduğu
/// için içerik "tutarlı" sayılıyordu, ama `answersFor`/`correctAnswerFor`
/// aynı index'te durduğu varsayımıyla çalışır (bkz. quiz_question.dart
/// başındaki not) — o varsayım burada kırıktı. Türkçe oyuncuya doğru şık
/// başka bir kutuda görünüyor ya da hiç görünmüyordu; Kurmancî turu
/// etkilenmiyordu, kusur yalnız TR arayüzde vardı.
///
/// ## Niçin sessiz kalırdı
///
/// `turkish_coverage_test.dart` yalnız çeviri VAR MI diye bakar.
/// `turkish_translation_integrity_test.dart` boşluk, birebir kopya ve aşırı
/// uzunluk sapması gibi mekanik izleri arar. `playable_inventory_test.dart`
/// yalnız SAYAR. Hiçbiri iki dizinin karşılıklı SIRASINI karşılaştırmaz;
/// bir şık kümesi baştan sona yanlış sırayla dursa bile hepsi yeşil kalır.
/// Kusur ancak TR arayüzde soruyu çözüp yanlış şıkkın işaretlendiğini gören
/// bir kullanıcıya görünürdü.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// `QuizQuestion._hasConsistentTurkishAnswers` özel (private) olduğu için
/// buradan çağrılamaz; bekçinin süzgeci onunla BİLEREK aynı üyelik kuralını
/// taşır (uzunluk eşit, boş şık yok, doğru cevap kümede var) — tam o alanın
/// gözden kaçırdığı SIRA denetimini bu bekçi ayrıca ve asıl burada yapar.
/// İki tanım birbirinden ayrışırsa (örn. üyelik kuralı gevşerse) bu bekçi
/// de güncellenmelidir.
bool _hasConsistentTurkishAnswers(QuizQuestion question) {
  final translated = question.answersTr;
  if (translated == null || translated.length != question.answers.length) {
    return false;
  }
  if (translated.any((option) => option.trim().isEmpty)) return false;
  final correctTr = question.correctAnswerTr?.trim();
  if (correctTr == null || correctTr.isEmpty) return false;
  return translated.map((option) => option.trim()).contains(correctTr);
}

void main() {
  const policy = QuestionContentPolicy();

  late List<QuizQuestion> inScope;

  setUpAll(() {
    inScope = QuestionBankLoader.instance.allQuestions
        .where(policy.isPlayable)
        .where(_hasConsistentTurkishAnswers)
        .toList();
  });

  test('oynanabilir ve Türkçesi tutarlı en az bir soru bankada var', () {
    // Süzgecin kendisi bozulup her şeyi elerse aşağıdaki `isEmpty` testi
    // anlamsızca yeşil kalır; bu test o sessiz kaçışı kapatır.
    expect(inScope, isNotEmpty);
  });

  test('her soruda Türkçe doğru şık, Kurmancî doğru şıkla AYNI indekste', () {
    final misaligned = <String>[];
    for (final q in inScope) {
      final answersTr = q.answersTr!;
      if (answersTr.length != q.answers.length) {
        // _hasConsistentTurkishAnswers zaten eledi ama açıkça belgelensin.
        misaligned.add('${q.id}: answersTr.length != answers.length');
        continue;
      }
      final kuIndex = q.answers.indexOf(q.correctAnswer);
      final trIndex = answersTr.indexOf(q.correctAnswerTr!.trim());
      if (kuIndex != trIndex) {
        misaligned.add(
          '${q.id}: KU doğru şık #$kuIndex ("${q.correctAnswer}"), '
          'TR doğru şık #$trIndex ("${q.correctAnswerTr}") — '
          'answers=${q.answers} answersTr=$answersTr',
        );
      }
    }

    expect(
      misaligned,
      isEmpty,
      reason:
          'Bu sorularda Türkçe arayüz YANLIŞ şıkkı doğru işaretler — '
          'answersTr[i], answers[i]\'nin çevirisi değil:\n'
          '${misaligned.join('\n')}',
    );
  });
}
