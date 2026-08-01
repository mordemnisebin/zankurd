import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Açıklamasız soru sayısı YALNIZ AZALIR.
///
/// ## Niçin önemli
///
/// Sonuç ekranındaki "bütün açıklamalar" kartı, `getLocalizedExplanation`
/// boş dönen soruları hiç listelemez — boş bir satır göstermek açıklama
/// olmamasından kötüdür. Karar doğru ama sonucu şu: açıklaması olmayan
/// soru, oyuncunun öğrenme akışından SESSİZCE düşüyor. Tur bitiyor,
/// yanlış yaptığı soru listede hiç görünmüyor ve niçin yanlış olduğunu
/// öğrenemiyor.
///
/// Ölçüm (2026-08-01): 1787 sorunun 15'inde hiçbir dilde açıklama yok ve
/// **hepsi `community_questions.json` içinde** — topluluk katkısı sorular
/// açıklama alanı boş gönderilebiliyor.
///
/// ## Niçin sıfır değil
///
/// Onbeşi de belirli kişiler ve olaylar hakkında (şehitler, sanatçılar,
/// siyasetçiler). Açıklama yazmak olgu bilgisi ister; uydurulmuş bir
/// açıklama, açıklamasızlıktan çok daha kötüdür. Bunlar editör
/// masasında.
///
/// Tavan bu yüzden var: sayı artamaz. Açıklama yazıldıkça bu sabit
/// düşürülür.
void main() {
  /// Bugünkü sayı. **YALNIZ AZALTILABİLİR.**
  const ceiling = 15;

  test('açıklamasız soru sayısı tavanı aşmıyor', () {
    final missing = <String>[];
    var total = 0;
    for (final asset in questionBankAssets) {
      final file = File(asset);
      if (!file.existsSync()) continue;
      for (final row in (jsonDecode(file.readAsStringSync()) as List)) {
        final question = QuizQuestion.fromJson(row as Map<String, dynamic>);
        total++;
        final any = [
          question.explanation,
          question.explanationTr ?? '',
          question.explanationKu ?? '',
        ].any((text) => text.trim().isNotEmpty);
        if (!any) missing.add('${asset.split('/').last}/${question.id}');
      }
    }

    expect(
      total,
      greaterThan(1000),
      reason: 'Bekçi kör kalmasın: banka yüklenemediyse sayı boşa sıfırdır.',
    );
    expect(
      missing.length,
      lessThanOrEqualTo(ceiling),
      reason:
          'Açıklamasız soru sayısı ${missing.length}, tavan $ceiling. Yeni '
          'soru açıklamasız eklenmiş olabilir:\n${missing.join("\n")}',
    );
    if (missing.length < ceiling) {
      // ignore: avoid_print
      print('Tavan düşürülebilir: $ceiling → ${missing.length}');
    }
  });

  test('boş açıklama sonuç ekranında satır üretmiyor', () {
    // Kural, tavanın niçinini taşıyan davranış: boş açıklama gizlenir.
    // Gizlendiği için de kimse fark etmez — tavan bu yüzden gerekli.
    final source = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('Boş ya da şablon açıklamalar hiç listelenmez'),
      reason:
          'Davranış değiştiyse bu bekçinin gerekçesi de gözden '
          'geçirilmeli.',
    );
  });
}
