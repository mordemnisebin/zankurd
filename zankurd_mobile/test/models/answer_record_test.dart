import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';

void main() {
  group('AnswerRecord', () {
    const testRecord = AnswerRecord(
      id: 'q_001',
      category: 'Ziman',
      prompt: 'Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?',
      answers: ['Bilmek', 'Gitmek', 'Okumak', 'Yazmak'],
      correctAnswer: 'Bilmek',
      selectedAnswer: 'Bilmek',
      explanation: 'Zanîn bilgi ve bilmek anlamına gelir.',
    );

    test('isCorrect returns true when selectedAnswer equals correctAnswer', () {
      expect(testRecord.isCorrect, true);
    });

    test('isCorrect returns false when selectedAnswer differs from correctAnswer',
        () {
      const incorrectRecord = AnswerRecord(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test?',
        answers: ['A', 'B', 'C'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: 'Exp',
      );

      expect(incorrectRecord.isCorrect, false);
    });

    test('isUnanswered returns true when selectedAnswer is null', () {
      const unansweredRecord = AnswerRecord(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test?',
        answers: ['A', 'B', 'C'],
        correctAnswer: 'A',
        selectedAnswer: null,
        explanation: 'Exp',
      );

      expect(unansweredRecord.isUnanswered, true);
    });

    test('isUnanswered returns true when selectedAnswer is empty', () {
      const emptyRecord = AnswerRecord(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test?',
        answers: ['A', 'B', 'C'],
        correctAnswer: 'A',
        selectedAnswer: '',
        explanation: 'Exp',
      );

      expect(emptyRecord.isUnanswered, true);
    });

    test('hasImage returns true when imageUrl is not empty', () {
      const recordWithImage = AnswerRecord(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test?',
        answers: ['A', 'B', 'C'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: 'Exp',
        imageUrl: 'assets/image.jpg',
      );

      expect(recordWithImage.hasImage, true);
    });

    test('hasImage returns false when imageUrl is null', () {
      expect(testRecord.hasImage, false);
    });
  });
}
