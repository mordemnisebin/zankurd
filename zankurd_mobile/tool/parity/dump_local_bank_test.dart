/// Yerel soru bankasını, uygulamanın GÖRDÜĞÜ biçimde JSON'a döker.
///
/// Bu bir test değil, bir araç: `tool/sync_local_parity_to_server.py`
/// sunucuyla karşılaştırmadan önce bunu çalıştırır. `flutter test` olarak
/// yazıldı çünkü `QuestionBankLoader` Flutter'a bağlı (`dart run` ile
/// açılmaz); `tool/screenshots/` altındaki betiklerle aynı yol.
///
/// ## Niçin Dart, niçin Python değil
///
/// Oynanabilirlik kuralı (`QuestionContentPolicy.isPlayable`: gizli kategori,
/// emekli id, `reviewStatus`, yapısal geçerlilik) bir kez Python'a kopyalanmıştı
/// (`sync_sinema_to_server.py`). Kopya ile asıl kural ayrışırsa sunucu göçü
/// sessizce başka bir kümeyi taşır. Burada süzgeç, uygulamanın kendi
/// sınıflarıyla uygulanır; Python yalnız sonucu okur.
///
/// ## Çıktı
///
/// `ZANKURD_PARITY_OUT` (varsayılan `.tmp/parity/local_bank.json`) dosyasına,
/// yüklenen HER soru için bir kayıt yazar: `playable` bayrağı ve elenmişse
/// `reason` (`hidden_category`, `retired`, `review_status`, `invalid:<kod>`).
/// Emekli/oynanamaz soruların da dökülmesi bilerek: sunucuda hâlâ onaylı duran
/// «bilinen kötü» kopyalar metin eşleşmesiyle bulunur.
///
/// Kullanım (zankurd_mobile/ içinden):
///   flutter test tool/parity/dump_local_bank_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/content_quality_policy.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

void main() {
  test('yerel bankayı JSON olarak dök', () {
    const policy = QuestionContentPolicy();
    const quality = ContentQualityPolicy();
    final out = File(
      Platform.environment['ZANKURD_PARITY_OUT'] ??
          '.tmp/parity/local_bank.json',
    );
    out.parent.createSync(recursive: true);

    final records = <Map<String, Object?>>[];
    for (final q in QuestionBankLoader.instance.allQuestions) {
      final playable = policy.isPlayable(q);
      records.add({
        'id': q.id,
        'category': q.category,
        'type': q.type.name,
        'prompt': q.prompt,
        'promptTr': q.promptTr,
        'answers': q.answers,
        'correctAnswer': q.correctAnswer,
        'explanation': q.explanation,
        'explanationKu': q.explanationKu,
        'explanationTr': q.explanationTr,
        'difficulty': q.difficulty,
        'imageUrl': q.imageUrl,
        'sourceTitle': q.metadata?.sourceTitle,
        'sourceReference': q.metadata?.sourceReference,
        'qualityVersion': q.metadata?.qualityVersion,
        'reviewStatus': q.metadata?.reviewStatus?.name,
        'playable': playable,
        'reason': playable ? null : _reason(q, quality, policy),
      });
    }
    out.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(records),
      flush: true,
    );
    final playableCount = records.where((r) => r['playable'] == true).length;
    // ignore: avoid_print
    print(
      'parity: ${records.length} kayıt, $playableCount oynanabilir -> '
      '${out.path}',
    );
    expect(records, isNotEmpty);
  });
}

/// Elenme nedeni; `isPlayable`in kontrol sırasıyla aynı.
String _reason(
  QuizQuestion q,
  ContentQualityPolicy quality,
  QuestionContentPolicy policy,
) {
  if (!isCategoryVisible(q.category)) return 'hidden_category';
  if (isQuestionRetired(q.id)) return 'retired';
  if (!quality.isEligible(q.metadata)) return 'review_status';
  final issues = policy.validate(q);
  return issues.isEmpty ? 'unknown' : 'invalid:${issues.first}';
}
