import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

QuizQuestion _question(String id, {String? prompt}) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: prompt ?? 'Pirs $id',
  answers: const ['a', 'b', 'c', 'd'],
  correctAnswer: 'a',
  explanation: 'rave',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SeenQuestionStore.resetInstance();
  });

  test('prefers unseen questions over seen ones', () async {
    final store = await SeenQuestionStore.load();
    final pool = List.generate(10, (i) => _question('q$i'));

    await store.markSeen(['q0', 'q1', 'q2', 'q3', 'q4', 'q5', 'q6']);

    final selected = store.preferUnseen(pool, 3, random: Random(1));
    final ids = selected.map((q) => q.id).toSet();
    expect(ids, {'q7', 'q8', 'q9'});
  });

  test('fills with seen questions when unseen are not enough', () async {
    final store = await SeenQuestionStore.load();
    final pool = List.generate(5, (i) => _question('q$i'));

    await store.markSeen(['q0', 'q1', 'q2']);

    final selected = store.preferUnseen(pool, 5, random: Random(1));
    expect(selected.length, 5);
    // Görülmemişler başta gelir.
    expect({selected[0].id, selected[1].id}, {'q3', 'q4'});
  });

  test('resets tracking when the whole pool has been seen', () async {
    final store = await SeenQuestionStore.load();
    final pool = List.generate(4, (i) => _question('q$i'));

    await store.markSeen(pool.map((q) => q.id));
    expect(store.seenCount, 4);

    final selected = store.preferUnseen(pool, 2, random: Random(1));
    expect(selected.length, 2);
    expect(store.seenCount, 0);
  });

  test('persists seen ids across instances', () async {
    final store = await SeenQuestionStore.load();
    await store.markSeen(['q1', 'q2']);

    SeenQuestionStore.resetInstance();
    final restored = await SeenQuestionStore.load();
    expect(restored.isSeen('q1'), isTrue);
    expect(restored.isSeen('q2'), isTrue);
    expect(restored.isSeen('q3'), isFalse);
  });

  test('returns empty selection for empty pool or zero limit', () async {
    final store = await SeenQuestionStore.load();
    expect(store.preferUnseen(const [], 5), isEmpty);
    expect(store.preferUnseen([_question('q1')], 0), isEmpty);
  });

  test('never returns the same prompt twice in one selection', () async {
    final store = await SeenQuestionStore.load();
    // Aynı prompt, farklı id/zorluk (zorluk katmanı kopyaları gibi).
    final pool = [
      _question('a1', prompt: 'roj nedir?'),
      _question('a2', prompt: 'roj nedir?'),
      _question('a3', prompt: 'roj nedir?'),
      _question('b1', prompt: 'av nedir?'),
      _question('b2', prompt: 'av nedir?'),
      _question('c1', prompt: 'mal nedir?'),
    ];

    final selected = store.preferUnseen(pool, 6, random: Random(3));
    final prompts = selected.map((q) => q.prompt).toList();
    expect(
      prompts.toSet().length,
      prompts.length,
      reason: 'Seçimde tekrar eden prompt olmamalı: $prompts',
    );
    // Yalnızca 3 benzersiz prompt var; limit 6 olsa da 3 dönmeli.
    expect(selected.length, 3);
  });

  test(
    'prompt dedupe still recycles when all prompts have been seen',
    () async {
      final store = await SeenQuestionStore.load();
      final pool = [
        _question('a1', prompt: 'roj nedir?'),
        _question('a2', prompt: 'roj nedir?'),
        _question('b1', prompt: 'av nedir?'),
      ];
      await store.markSeen(['a1', 'a2', 'b1']);

      final selected = store.preferUnseen(pool, 3, random: Random(1));
      final prompts = selected.map((q) => q.prompt).toList();
      expect(prompts.toSet().length, prompts.length);
      expect(selected.length, 2); // 'roj nedir?' ve 'av nedir?'
    },
  );
}
