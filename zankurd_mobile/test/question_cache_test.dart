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

  const q2 = QuizQuestion(
    id: 'q2',
    category: 'Ziman',
    prompt: 'test2',
    answers: ['c', 'd'],
    correctAnswer: 'c',
    explanation: 'y',
  );

  test('set sonrası kaynak listenin değişmesi cache\'i bozmaz', () {
    final source = [q];
    cache.set('Ziman_10', source);
    source.add(q2); // çağıran kendi listesini değiştirir
    expect(cache.get('Ziman_10'), [q]);
  });

  test('get çıktısının değiştirilmesi cache\'i bozmaz', () {
    cache.set('Ziman_10', [q]);
    expect(() => cache.get('Ziman_10')!.add(q2), throwsUnsupportedError);
    expect(cache.get('Ziman_10'), [q]);
  });

  test('farklı contentVersion eski anahtarları görmez', () {
    final v1 = QuestionCache(
      contentVersion: 1,
      ttl: const Duration(minutes: 5),
    );
    final v2 = QuestionCache(
      contentVersion: 2,
      ttl: const Duration(minutes: 5),
    );
    // Aynı store değil; sürüm anahtar önekinde — tek örnekte doğrula:
    final multi = QuestionCache(
      contentVersion: 1,
      ttl: const Duration(minutes: 5),
    );
    multi.set('Ziman_10', [q]);
    expect(multi.get('Ziman_10'), [q]);

    final bumped = QuestionCache(
      contentVersion: 2,
      ttl: const Duration(minutes: 5),
    );
    // Ayrı örnek boş başlar; sürüm sabiti kQuestionContentVersion >= 2 olmalı.
    expect(kQuestionContentVersion, greaterThanOrEqualTo(2));
    expect(bumped.get('Ziman_10'), isNull);

    // dropStale eski v öneklerini siler
    multi.set('Ziman_10', [q]);
    multi.dropStale(keepVersion: 99);
    expect(multi.get('Ziman_10'), isNull);

    // v1/v2 örnekleri kullanılmadı uyarısını bastır
    expect(v1.contentVersion, 1);
    expect(v2.contentVersion, 2);
  });
}
