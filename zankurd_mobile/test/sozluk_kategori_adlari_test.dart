import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';

/// Sözlük kategori adları öğrenme sekmeleriyle aynı (2026-10-15).
///
/// ## Kusur
///
/// Sözlük kaynakları dilbilgisine "Gramer", zamana "Demjimêr" diyordu; öğrenme
/// sekmeleri ise bilerek "Rêziman" ve "Dem" der (`Demjimêr` saat demektir).
/// Aynı konu iki ekranda iki adla çıkıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Sözlük testi yalnız kategori adlarının BOŞ OLMADIĞINA bakıyordu; adlar iki
/// yerde elle yazıldığı için biri düzeltilince öteki unutuldu.
///
/// ## Bekçi
///
/// Kimliği öğrenme kategorisiyle başlayan her sözlük kaynağı, `LearningScreen`
/// sekme etiketiyle (Kurmancî ve Türkçe) aynı kategori adını taşır.
void main() {
  test('sözlük kategori adları öğrenme sekme etiketleriyle aynı', () {
    final source = File(
      'lib/src/screens/learning_screen.dart',
    ).readAsStringSync();
    final labels = {
      for (final m in RegExp(
        r"'(\w+)': \('([^']+)', '([^']+)'\)",
      ).allMatches(source.substring(source.indexOf('_categoryLabel'))))
        m.group(1)!: (m.group(2)!, m.group(3)!),
    };
    expect(labels.keys, containsAll(['grammar', 'time', 'everyday']));

    final mismatches = <String>[];
    for (final lexiconSource in LearnerLexicon.sources.values) {
      final key = lexiconSource.id.split('_').first;
      final label = labels[key];
      if (label == null) continue;
      if (lexiconSource.categoryKu != label.$1 ||
          lexiconSource.categoryTr != label.$2) {
        mismatches.add(
          '${lexiconSource.id}: ${lexiconSource.categoryKu}/'
          '${lexiconSource.categoryTr} ≠ ${label.$1}/${label.$2}',
        );
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    expect(
      LearnerLexicon.sources.values.map((s) => s.categoryKu),
      isNot(anyOf(contains('Gramer'), contains('Demjimêr'))),
    );
  });
}
