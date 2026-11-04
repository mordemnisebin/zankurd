/// "xew" sorusunun doğru şıkkı yazı fiiliyle karışmamalı.
///
/// ## Kusur
///
/// Simülatör turu 5'te oyuncu, doğru şıkkı "nivistina mirovan"ı (nivistin =
/// uyumak) "yazma" sandı ve soruda "uyku" şıkkı olmadığını bildirdi.
///
/// ## Niçin sessiz kaldı
///
/// Anahtar doğruydu; yalnız şık metni nivîsîn (yazmak) ile görsel olarak
/// karışıyordu. Hiçbir bekçi doğru şıkkın okunabilirliğine bakmıyordu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dosya in [
    'assets/data/deepseek_verified_2026_09_30_questions.json',
  ]) {
    test('$dosya: xew sorusunun doğru şıkkı "razana mirovan"', () {
      final liste = jsonDecode(File(dosya).readAsStringSync()) as List;
      final soru =
          liste.firstWhere((q) => (q as Map)['id'] == 'ds_ziman_0138') as Map;
      expect(soru['correctAnswer'], 'razana mirovan');
      expect(soru['answers'], contains('razana mirovan'));
      expect(soru['answers'], isNot(contains('nivistina mirovan')));
    });
  }

  test('göç yalnız bu soruyu eski metne bağlı günceller', () {
    final sql = File('supabase/2026-11-09_xew_sik.sql').readAsStringSync();
    expect(sql, contains("id = '75c2140f-7d76-5625-9dc6-d256096a5783'"));
    expect(sql, contains("option_c = 'nivistina mirovan'"));
    expect(sql, isNot(contains('delete')));
  });
}
