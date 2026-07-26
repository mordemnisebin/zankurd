import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Açıklama kalitesi bekçisi.
///
/// 2026-07-25 canlı denetimi: cevap verildikten sonra açılan "Açıklama ·
/// Zana" paneli, soruların bir bölümünde hiçbir şey öğretmiyordu. İki
/// kalıp saf gürültüydü:
///
///   • "…îdiaya di vê pirsê de ne rast e; bersiva rast 'Şaş' e."
///     Cevap zaten ekranda yeşil olarak duruyor.
///   • "misafirperverlik Kürt kültürü kategorisinde ele alınır."
///     Kategori zaten soru kartının üstünde çip olarak yazıyor.
///
/// Bunlar `tool/strip_empty_explanations.py` ile temizlendi. Boş açıklamada
/// panel hiç açılmadığı için sonuç "öğretmeyen panel" yerine "panel yok"
/// olur — sessiz ama dürüst.
///
/// Bu test kalıpların bankaya geri sızmasını engeller. Yeni soru üreten
/// araçlar bu şablonları yeniden kullanırsa burada yakalanır.
void main() {
  test('soru bankasında bilgi taşımayan açıklama kalıbı yok', () {
    final file = File('assets/data/offline_questions.json');
    expect(file.existsSync(), isTrue, reason: 'soru bankası bulunamadı');

    final questions = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    expect(questions, isNotEmpty);

    final noise = RegExp(
      r"îdiaya di vê pirsê de|bersiva rast\s*['«]"
      r'|kategorisinde ele alınır|kategorisinde değerlendirilir'
      r'|têgeheke derbasdar e|geçerli bir kavramdır',
      caseSensitive: false,
    );

    final offenders = <String>[];
    for (final question in questions) {
      for (final field in ['explanation', 'explanationKu', 'explanationTr']) {
        final value = (question[field] as String?) ?? '';
        if (value.isNotEmpty && noise.hasMatch(value)) {
          offenders.add('${question['id']} ($field): $value');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bilgi taşımayan açıklama kalıbı geri gelmiş '
          '(${offenders.length} adet). İlk üç örnek:\n'
          '${offenders.take(3).join("\n")}\n'
          'Temizlemek için: python3 tool/strip_empty_explanations.py',
    );
  });

  test('açıklama alanı olan sorularda metin anlamlı uzunlukta', () {
    final file = File('assets/data/offline_questions.json');
    final questions = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    // Boş bırakmak serbest (panel açılmaz); ama dolu bırakılıp tek kelime
    // yazmak paneli açar ve yine hiçbir şey öğretmez.
    final tooShort = questions.where((q) {
      final value = ((q['explanation'] as String?) ?? '').trim();
      return value.isNotEmpty && value.length < 12;
    }).toList();

    expect(
      tooShort,
      isEmpty,
      reason:
          '${tooShort.length} soruda açıklama var ama 12 karakterden kısa; '
          'panel açılır, içerik vermez.',
    );
  });
}
