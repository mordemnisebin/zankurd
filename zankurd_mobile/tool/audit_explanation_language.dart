// Türkçe arayüzde Kurmancî görünen açıklamaları sayar.
//
// `QuizQuestion.getLocalizedExplanation(false)` Türkçe alan yoksa ham
// `explanation` metnini olduğu gibi döndürür; o metin Kurmancî ise Türkçe
// oyuncu okuyamadığı bir açıklama görür. Sayım `QuestionLanguagePolicy`
// ile yapılır ki rapor ile bekçi ayrışmasın.
import 'dart:convert';
import 'dart:io';

import 'package:zankurd_mobile/src/data/curated_question_bank.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

void main(List<String> args) {
  // `sentence_building_questions.json` bu listede eksikti; banka adları
  // artık `questionBankAssets`ten türetiliyor ki yeni bir banka eklendiğinde
  // denetim kendiliğinden kapsasın.
  final banks = <String, List<QuizQuestion>>{
    for (final asset in questionBankAssets)
      asset.split('/').last.replaceAll('_questions.json', ''): _fromJson(asset),
    'curated': curatedQuestionBank,
  };

  var total = 0;
  final samples = <String>[];
  banks.forEach((name, questions) {
    var count = 0;
    for (final question in questions) {
      // Varsayılan: **Türkçe** gösterimde Kurmancî metin kalmış mı?
      // `--ku`: **Kurmancî** gösterimde Türkçe metin kalmış mı? (ayna kusur)
      final isKu = args.contains('--ku');
      final wanted = isKu ? 'tr' : 'ku';
      final text = question.getLocalizedExplanation(isKu);
      if (text.trim().isEmpty) continue;
      if (QuestionLanguagePolicy.detectSentenceLanguage(text) != wanted) {
        continue;
      }
      count++;
      if (samples.length < 12) {
        samples.add('$name/${question.id}: $text');
      }
    }
    stdout.writeln('$name: $count / ${questions.length}');
    total += count;
  });
  stdout.writeln('TOPLAM: $total');
  if (args.contains('--samples')) {
    for (final sample in samples) {
      stdout.writeln('  $sample');
    }
  }
}

List<QuizQuestion> _fromJson(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  return (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>()
      .map(QuizQuestion.fromJson)
      .toList();
}
