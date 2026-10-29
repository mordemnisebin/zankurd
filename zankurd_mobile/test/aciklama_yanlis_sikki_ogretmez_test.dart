import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Türkçe açıklama doğru cevabı değil, YANLIŞ bir şıkkı öğretmez.
///
/// ## Kusur (Codex denetimi 2026-10-29, içerik #2)
///
/// `ziman_x_0014`: "At hayvanının Kurmancî adı?" sorusunun doğru cevabı
/// "Hesp"; açıklama ise "Bizin, Türkçede "keçi" demektir." diyordu. Öğrenci
/// doğru cevabı verince bile geri bildirim başka bir şıkkı (keçi) öğretiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Açıklama metni hiçbir testte soruyla birlikte okunmuyordu: cevap
/// anahtarı testleri doğru şıkkı, açıklama testleri biçimi sınıyordu;
/// "açıklama doğru cevaptan mı söz ediyor" sorusunu kimse sormuyordu.
///
/// ## Kural
///
/// Açıklama "X, Türkçede "y" demektir." kalıbındaysa X, YANLIŞ bir şıkka
/// eşit ve doğru cevaba eşit değilse kayıt kusurludur. (Kalıp dar tutuldu:
/// açıklamalar yanlış şıkları kasıtlı karşılaştırabilir; yalnız tek-cümlelik
/// tanım kalıbı doğru cevabı öğretmek zorundadır.)
void main() {
  final pattern = RegExp(r'^([^\s,]+), Türkçede "[^"]+" demektir\.$');

  test(
    'tek cümlelik "X, Türkçede y demektir" açıklaması doğru cevabı öğretir',
    () {
      final offenders = <String>[];
      for (final asset in questionBankAssets) {
        final file = File(asset);
        if (!file.existsSync()) continue;
        final list = json.decode(file.readAsStringSync()) as List<dynamic>;
        for (final raw in list) {
          final q = raw as Map<String, dynamic>;
          final explanation =
              (q['explanationTr'] ?? q['explanation']) as String?;
          if (explanation == null) continue;
          final match = pattern.firstMatch(explanation.trim());
          if (match == null) continue;
          final subject = match.group(1)!.toLowerCase();
          final correct = (q['correctAnswer'] as String? ?? '').toLowerCase();
          final answers = [
            for (final a in (q['answers'] as List<dynamic>? ?? const []))
              (a as String).toLowerCase(),
          ];
          if (subject != correct && answers.contains(subject)) {
            offenders.add('${q['id']}: $explanation');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );
}
