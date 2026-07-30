import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader_io.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  test('Flutter test yükleyicisi community bankasını da içerir', () {
    final questions = QuestionBankLoader.instance.allQuestions;

    expect(
      questions.any((question) => question.id.startsWith('comm_')),
      isTrue,
      reason:
          'Üretim community_questions.json dosyasını yüklüyor; test '
          'yükleyicisi aynı bankayı atlamamalı.',
    );
  });

  test('bir asset bozuksa test yükleyicisi sağlam bankalarla devam eder', () {
    final originalDirectory = Directory.current.path;
    final tempDirectory = Directory.systemTemp.createTempSync(
      'zankurd_question_loader_',
    );
    addTearDown(() {
      Directory.current = originalDirectory;
      tempDirectory.deleteSync(recursive: true);
    });

    final dataDirectory = Directory('${tempDirectory.path}/assets/data')
      ..createSync(recursive: true);

    void writeBank(String filename, String questionId) {
      final question = QuizQuestion(
        id: questionId,
        category: 'test',
        prompt: 'Pirs?',
        answers: const ['A', 'B'],
        correctAnswer: 'A',
        explanation: 'Şîrove.',
      );
      File(
        '${dataDirectory.path}/$filename',
      ).writeAsStringSync(jsonEncode([question.toJson()]));
    }

    writeBank('offline_questions.json', 'test_offline');
    writeBank('editorial_questions.json', 'test_editorial');
    writeBank('sentence_building_questions.json', 'test_sentence');
    // community_questions.json bilinçli olarak yok: üretim yükleyicisi
    // tek asset hatasında diğer bankaları koruyor.
    Directory.current = tempDirectory.path;

    final questions = loadSyncIfInTest();

    expect(questions, isNotNull);
    expect(
      questions!.map((question) => question.id),
      containsAll(const ['test_sentence', 'test_editorial', 'test_offline']),
    );
  });
}
