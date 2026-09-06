/// Sayısal şıkların ekranda SIRALI göründüğünün bekçisi.
///
/// ## Kusur
///
/// `displayAnswers` bütün şıkları id'den türeyen sabit bir kaydırmayla
/// DÖNDÜRÜYORDU. Döndürme göreli sırayı korur, dolayısıyla bankada
/// karışık duran sayılar ekranda da karışık kalıyordu. Oyuncuya
/// "Evdalê Zeynikê hangi yüzyılda yaşadı?" sorusu şu şıklarla geliyordu:
///
///     A) 20.   B) 19.   C) 15.   D) 17.
///
/// Bankadaki 85 tam sayısal sorunun 69'u böyleydi (2026-08-24,
/// simülatörde ilk soruda görüldü).
///
/// ## Niçin kusur
///
/// Karışık sayı soruyu zorlaştırmaz, OKUMAYI zorlaştırır. Oyuncu olguyu
/// düşünmek yerine dört sayıyı zihninde sıraya koymakla uğraşır. Ölçmek
/// istediğimiz şey tarih bilgisi; eklenen yük ona ait değil.
///
/// ## Niçin sessiz kaldı
///
/// Hiçbir kapı şık SIRASINA bakmıyordu. `question_bank_test` doğru
/// cevabın KONUM dengesini ölçer (yayılım ≤ 1) ve karışık sıra o ölçütü
/// bozmaz — hatta besler. İçerik tarayıcısı da sızıntı arıyordu, düzen
/// değil. Kusur ancak uygulama gerçekten oynanınca görünür.
///
/// ## Denge nasıl korunuyor
///
/// Sıralama yönü (artan/azalan) aynı kararlı tohumdan seçilir, böylece
/// doğru cevap sorular ARASINDA yine dört konuma dağılır. Denge tek
/// soruyu karıştırarak değil, sorular arası yön değiştirerek sağlanır.
/// `tool/rebalance_answer_positions.py` bu soruları sayar ama taşımaz.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

num? _asNumber(String option) {
  final trimmed = option.trim().replaceAll('.', '');
  return trimmed.isEmpty ? null : num.tryParse(trimmed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tamamı sayısal olan şıklar ekranda sıralı gelir', () {
    final questions = [
      for (final asset in questionBankAssets)
        if (File(asset).existsSync())
          ...(jsonDecode(File(asset).readAsStringSync()) as List).map(
            (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
          ),
    ];
    expect(
      questions.length,
      greaterThan(500),
      reason: 'Bekçi kör kalmasın: banka yüklenemediyse test anlamsızdır.',
    );

    final bozuk = <String>[];
    var sayisalSoru = 0;

    for (final question in questions) {
      if (question.type == QuestionType.trueFalse) continue;
      final shown = question.displayAnswers;
      if (shown.length < 3) continue;

      final values = shown.map(_asNumber).toList();
      if (values.any((v) => v == null)) continue;

      sayisalSoru++;
      final numbers = values.cast<num>().toList();
      final artan = List<num>.of(numbers)..sort();
      final azalan = artan.reversed.toList();
      final sirali = _ayni(numbers, artan) || _ayni(numbers, azalan);
      if (!sirali) {
        bozuk.add('${question.id}: $shown');
      }
    }

    expect(
      sayisalSoru,
      greaterThan(30),
      reason:
          'Bekçi kör kalmasın: sayısal şıklı soru bulunamadıysa ölçüt '
          'değişmiş olabilir (sayı ayrıştırma kuralı?).',
    );
    expect(
      bozuk,
      isEmpty,
      reason:
          'Bu soruların sayısal şıkları ekranda karışık sırada '
          'geliyor:\n${bozuk.take(10).join("\n")}',
    );
  });
}

bool _ayni(List<num> a, List<num> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
