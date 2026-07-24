import 'dart:convert';
import 'dart:io';

import '../models/quiz_question.dart';
import 'curated_question_bank.dart';

List<QuizQuestion>? loadSyncIfInTest() {
  try {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) return null;
    final offlineRaw = File('assets/data/offline_questions.json').readAsStringSync();
    final editorialRaw = File('assets/data/editorial_questions.json').readAsStringSync();
    final offline = (json.decode(offlineRaw) as List)
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>));
    final editorial = (json.decode(editorialRaw) as List)
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>));
    return [
      ...curatedQuestionBank,
      ...editorial,
      ...offline,
    ];
  } catch (_) {
    return null;
  }
}
