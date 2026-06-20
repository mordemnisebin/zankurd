import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MistakeStore.resetInstance();
  });

  test('wrong answers are stored once', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1');
    await store.markMistake('q1');
    await store.markMistake('q2');
    expect(store.count, 2);
    expect(store.contains('q1'), isTrue);
  });

  test('SM-2 Kolay (q = 5) increases ease factor and resolves after 5 reviews', () async {
    final store = await MistakeStore.load();
    
    // Initial mistake: sets easeFactor to 2.3, repetitions to 0, intervalDays to 1
    await store.markMistake('q1');
    expect(store.count, 1);
    
    // 1st review: Kolay (q = 5). EF: 2.3 -> 2.4, Reps: 0 -> 1, Interval: 1 day
    await store.markResolvedSM2('q1', 5);
    expect(store.count, 1);
    
    // 2nd review: Kolay (q = 5). EF: 2.4 -> 2.5, Reps: 1 -> 2, Interval: 6 days
    await store.markResolvedSM2('q1', 5);
    expect(store.count, 1);

    // 3rd review: Kolay (q = 5). EF: 2.5 -> 2.6, Reps: 2 -> 3, Interval: (6 * 2.5).round() = 15 days
    await store.markResolvedSM2('q1', 5);
    expect(store.count, 1);

    // 4th review: Kolay (q = 5). EF: 2.6 -> 2.7, Reps: 3 -> 4, Interval: (15 * 2.6).round() = 39 days
    // Since interval 39 >= 30, it should be resolved and removed!
    await store.markResolvedSM2('q1', 5);
    expect(store.count, 0); // Removed because intervalDays >= 30
  });

  test('SM-2 Zor (q = 3) decreases ease factor and resolves on 5th repetition', () async {
    final store = await MistakeStore.load();
    
    // Initial mistake: EF: 2.3, Reps: 0, Interval: 1 day
    await store.markMistake('q1');
    
    // 1st review: Zor (q = 3). EF: 2.3 -> 2.16, Reps: 1, Interval: 1 day
    await store.markResolvedSM2('q1', 3);
    expect(store.count, 1);

    // 2nd review: Zor (q = 3). EF: 2.16 -> 2.02, Reps: 2, Interval: 6 days
    await store.markResolvedSM2('q1', 3);
    expect(store.count, 1);

    // 3rd review: Zor (q = 3). EF: 2.02 -> 1.88, Reps: 3, Interval: (6 * 2.02).round() = 12 days
    await store.markResolvedSM2('q1', 3);
    expect(store.count, 1);

    // 4th review: Zor (q = 3). EF: 1.88 -> 1.74, Reps: 4, Interval: (12 * 1.88).round() = 23 days
    await store.markResolvedSM2('q1', 3);
    expect(store.count, 1); // Not resolved yet (reps = 4, interval = 23 < 30)

    // 5th review: Zor (q = 3). EF: 1.74 -> 1.6, Reps: 5, Interval: (23 * 1.74).round() = 40 days
    // Resolved because reps reaches 5 (and interval >= 30)
    await store.markResolvedSM2('q1', 3);
    expect(store.count, 0); // Removed!
  });

  test('daily history counts correct and wrong answers', () async {
    final store = await MistakeStore.load();
    
    await store.markMistake('q1'); // wrong +1
    await store.markResolved('q1'); // correct +1
    await store.markResolved('q2'); // correct +1 (even if q2 not a mistake, counted in history)

    final history = store.getLast7DaysHistory();
    final todayKey = history.keys.last;
    final todayData = history[todayKey];
    
    expect(todayData, isNotNull);
    expect(todayData!['wrong'], 1);
    expect(todayData['correct'], 2);
  });

  test('mistakes persist across instances', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1');

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load();
    expect(restored.contains('q1'), isTrue);
  });

  test('mistake category tracking and count', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1', category: 'Ziman');
    await store.markMistake('q2', category: 'Dîrok');
    await store.markMistake('q3', category: 'Ziman');

    final counts = store.getMistakesCountByCategory();
    expect(counts['Ziman'], 2);
    expect(counts['Dîrok'], 1);
  });
}
