import 'dart:convert';
import 'dart:io';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

void main() {
  final rows =
      (jsonDecode(File('assets/data/offline_questions.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  final out = <String, dynamic>{};
  for (final row in rows) {
    final q = QuizQuestion.fromJson(row);
    const isKu = !bool.fromEnvironment('tr');
    final text = q.getLocalizedExplanation(isKu);
    if (text.trim().isEmpty) continue;
    const wanted = isKu ? 'tr' : 'ku';
    if (QuestionLanguagePolicy.detectSentenceLanguage(text) != wanted) continue;
    out[q.id] = q.explanation;
  }
  stdout.writeln(jsonEncode(out));
}
