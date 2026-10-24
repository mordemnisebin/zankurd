// Oynanabilir paket sorularını ve canlı havuz dışı tarama için düz JSON'a
// döker. Uygulamanın kendi süzgecini (QuestionContentPolicy) kullanır, yani
// çıktı tam olarak oyuncunun görebileceği sorulardır.
//
// flutter test tool/soru_tarama/disari_aktar_test.dart
// Çıktı: ZANKURD_SORU_TARAMA_OUT (varsayılan /tmp/zk_tarama/paket.json)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

void main() {
  test('oynanabilir paket sorularını dök', () {
    const policy = QuestionContentPolicy();
    final out = <Map<String, Object?>>[];
    for (final asset in questionBankAssets) {
      final raw = jsonDecode(File(asset).readAsStringSync());
      final items = raw is List ? raw : (raw as Map)['questions'] as List;
      for (final item in items) {
        final q = QuizQuestion.fromJson(Map<String, dynamic>.from(item as Map));
        if (!policy.isPlayable(q)) continue;
        out.add({
          'id': q.id,
          'dosya': asset.split('/').last,
          'kategori': q.category,
          'tur': q.type.name,
          'soru': q.prompt,
          'siklar': q.answers,
          'dogru': q.correctAnswer,
          'soruTr': q.promptTr,
          'siklarTr': q.answersTr,
          'dogruTr': q.correctAnswerFor(isKu: false),
        });
      }
    }
    final path =
        Platform.environment['ZANKURD_SORU_TARAMA_OUT'] ??
        '/tmp/zk_tarama/paket.json';
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
    // ignore: avoid_print
    print('${out.length} soru -> $path');
    expect(out, isNotEmpty);
  });
}
