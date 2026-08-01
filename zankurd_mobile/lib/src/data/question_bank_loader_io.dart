import 'dart:convert';
import 'dart:io';

import '../models/quiz_question.dart';
import 'curated_question_bank.dart';
import 'question_bank_assets.dart';

List<QuizQuestion>? loadSyncIfInTest() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) return null;
  // Sıra `questionBankAssets` ile aynıdır; liste orada tek yerde durur.
  return [
    ...curatedQuestionBank,
    for (final asset in questionBankAssets) ..._loadBank(asset),
  ];
}

List<QuizQuestion> _loadBank(String assetPath) {
  try {
    final raw = File(assetPath).readAsStringSync();
    return (json.decode(raw) as List)
        .map((entry) => QuizQuestion.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  } catch (_) {
    // Üretim yükleyicisi gibi tek asset hatasında diğer bankalarla devam et.
    return const [];
  }
}
