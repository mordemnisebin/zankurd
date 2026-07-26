import 'dart:convert';
import 'dart:io';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

void main() {
  const policy = QuestionLanguagePolicy();
  final rows =
      (jsonDecode(File('assets/data/offline_questions.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  final out = <String, dynamic>{};
  for (final row in rows) {
    final q = QuizQuestion.fromJson(row);
    if (policy.isConsistent(q)) continue;
    out[q.id] = {
      'category': q.category,
      'prompt': q.prompt,
      'correct': q.correctAnswer,
      'answers': q.answers,
    };
  }
  stdout.writeln(const JsonEncoder.withIndent(' ').convert(out));
}
