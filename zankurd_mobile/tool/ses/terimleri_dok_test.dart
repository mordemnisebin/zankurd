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
    final seen = <String>{};
    final out = <Map<String, String>>[];
    for (final entry in LearnerLexicon.entries) {
      final key = kurmanciTextKey(entry.termKu);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add({'key': key, 'text': entry.termKu.trim()});
    }
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(out),
    );
  });
}
