// Sözlükteki bütün Kurmancî terimleri ses üretimi için JSON olarak döker.
//
// Sözlük Flutter'a bağlı olduğundan `dart run` değil test koşucusuyla:
//   ZANKURD_TERIM_CIKTI=/yol/terimler.json flutter test tool/ses/terimleri_dok_test.dart
// Çıktı: [{"key": ..., "text": ...}], anahtara göre tekil.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';

void main() {
  test('terimleri dök', () {
    final path = Platform.environment['ZANKURD_TERIM_CIKTI'];
    if (path == null || path.isEmpty) return;
    // ZANKURD_METIN_GIRDI verilirse (JSON metin listesi, ör. ders örnek
    // cümleleri) sözlük yerine o liste anahtarlanır.
    final input = Platform.environment['ZANKURD_METIN_GIRDI'];
    final texts = input == null || input.isEmpty
        ? [for (final entry in LearnerLexicon.entries) entry.termKu]
        : (jsonDecode(File(input).readAsStringSync()) as List).cast<String>();
    final seen = <String>{};
    final out = <Map<String, String>>[];
    for (final text in texts) {
      final key = kurmanciTextKey(text);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add({'key': key, 'text': text.trim()});
    }
    File(
      path,
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}
