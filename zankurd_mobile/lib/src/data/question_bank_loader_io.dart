import 'dart:convert';
import 'dart:io';

import '../models/quiz_question.dart';
import 'curated_question_bank.dart';

List<QuizQuestion>? loadSyncIfInTest() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) return null;
  final offline = _loadBank('assets/data/offline_questions.json');
  final editorial = _loadBank('assets/data/editorial_questions.json');
  final sentences = _loadBank('assets/data/sentence_building_questions.json');
  final community = _loadBank('assets/data/community_questions.json');
  return [
    ...curatedQuestionBank,
    ...sentences,
    ...community,
    ...editorial,
    ...offline,
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
