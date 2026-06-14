import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/question_cache.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  late QuestionCache cache;

  setUp(() => cache = QuestionCache(ttl: const Duration(seconds: 1)));

  const q = QuizQuestion(
    id: 'q1',
    category: 'Ziman',
    prompt: 'test',
    answers: ['a', 'b'],
    correctAnswer: 'a',
    explanation: 'x',
  );

  test('boş cache → null döner', () {
    expect(cache.get('Ziman_10'), isNull);
  });

  test('set sonrası get → aynı listeyi döner', () {
    cache.set('Ziman_10', [q]);
    expect(cache.get('Ziman_10'), [q]);
  });

  test('TTL dolunca null döner', () async {
    cache.set('Ziman_10', [q]);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(cache.get('Ziman_10'), isNull);
  });

  test('farklı key → birbirini etkilemez', () {
    cache.set('Ziman_10', [q]);
    expect(cache.get('Cografya_10'), isNull);
  });
}
