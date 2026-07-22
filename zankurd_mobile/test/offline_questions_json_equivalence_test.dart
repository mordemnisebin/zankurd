import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/offline_question_bank.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  test(
    'assets/data/offline_questions.json birebir offlineQuestionBank ile eşleşir',
    () async {
      final raw = await File(
        'assets/data/offline_questions.json',
      ).readAsString();
      final decoded = jsonDecode(raw) as List;
      final fromJson = decoded
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(fromJson.length, offlineQuestionBank.length);

      for (var i = 0; i < offlineQuestionBank.length; i++) {
        final a = offlineQuestionBank[i];
        final b = fromJson[i];
        expect(b.id, a.id, reason: 'index $i id');
        expect(b.category, a.category, reason: 'index $i category');
        expect(b.prompt, a.prompt, reason: 'index $i prompt');
        expect(b.answers, a.answers, reason: 'index $i answers');
        expect(
          b.correctAnswer,
          a.correctAnswer,
          reason: 'index $i correctAnswer',
        );
        expect(b.explanation, a.explanation, reason: 'index $i explanation');
        expect(
          b.explanationKu,
          a.explanationKu,
          reason: 'index $i explanationKu',
        );
        expect(
          b.explanationTr,
          a.explanationTr,
          reason: 'index $i explanationTr',
        );
        expect(b.type, a.type, reason: 'index $i type');
        expect(b.imageUrl, a.imageUrl, reason: 'index $i imageUrl');
        expect(b.difficulty, a.difficulty, reason: 'index $i difficulty');
        expect(
          b.metadata?.toJson(),
          a.metadata?.toJson(),
          reason: 'index $i metadata',
        );
      }
    },
  );

  test('soru bankası doğrulayıcısı varsayılan olarak dosya değiştirmez', () async {
    final jsonFile = File('assets/data/offline_questions.json');
    final dartFile = File('lib/src/data/offline_question_bank.dart');
    final jsonBefore = await jsonFile.readAsBytes();
    final dartBefore = await dartFile.readAsBytes();

    final result = await Process.run('python', [
      'tool/verify_and_fix_question_bank.py',
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(await jsonFile.readAsBytes(), jsonBefore);
    expect(await dartFile.readAsBytes(), dartBefore);
  });
}
