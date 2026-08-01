// Şık dili denetimi — `QuestionLanguagePolicy` ile aynı sınıflandırıcıyı
// kullanır, böylece rapor ile bekçi testi asla ayrışmaz.
//
// Kullanım: dart run tool/audit_option_languages.dart [--json]
import 'dart:convert';
import 'dart:io';

import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

// Banka listesi `questionBankAssets`ten gelir. Eskiden burada elle
// yazılmış iki yol vardı ve uygulamanın yüklediği DÖRT bankanın ikisini
// atlıyordu — en çok da `editorial_questions.json`ı. Denetim tam bu
// kusuru aramak için yazılmıştı ve baktığı yerde kusur olmadığı için
// "temiz" diyordu (2026-08-01).
const _banks = questionBankAssets;

void main(List<String> args) {
  const policy = QuestionLanguagePolicy();
  final offending = <String, List<String>>{};
  final givenAway = <String>[];
  var total = 0;

  for (final bank in _banks) {
    final file = File(bank);
    if (!file.existsSync()) continue;
    final rows = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    for (final row in rows) {
      total++;
      final question = QuizQuestion.fromJson(row);
      final bad = policy.offLanguageDistractors(question);
      if (bad.isNotEmpty) offending[question.id] = bad;
      if (policy.answerIsGivenAwayByLanguage(question)) {
        givenAway.add(question.id);
      }
    }
  }

  if (args.contains('--json')) {
    stdout.writeln(
      jsonEncode({'offending': offending, 'givenAway': givenAway}),
    );
    return;
  }
  stdout.writeln('toplam soru: $total');
  stdout.writeln('yabancı dilde çeldirici içeren: ${offending.length}');
  stdout.writeln('doğru cevabı dil ele veren: ${givenAway.length}');
}
