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

  // 2026-07-25 denetim bulgusu: eski mezuniyet eşiği (5 tekrar / 30 gün)
  // maddeyi 3-4 doğru cevaptan sonra sistemden tamamen siliyordu. SM-2'nin
  // değeri aylar süren aralıklardadır; eşikler 8 tekrar / 180 güne çekildi
  // ve mezun olan maddenin SRS geçmişi (easeFactor) korunuyor.
  test('SM-2 Kolay (q = 5) aralığı büyütür ama maddeyi erken silmez', () async {
    final store = await MistakeStore.load();

    await store.markMistake('q1');
    expect(store.count, 1);

    // Reps 1 → 1 gün, Reps 2 → 6 gün, Reps 3 → ~15 gün, Reps 4 → ~39 gün.
    for (var i = 0; i < 4; i++) {
      await store.markResolvedSM2('q1', 5);
      expect(
        store.count,
        1,
        reason: '${i + 1}. tekrardan sonra madde silinmemeli',
      );
    }

    // Reps 5 → ~105 gün: hâlâ 180 günün altında.
    await store.markResolvedSM2('q1', 5);
    expect(store.count, 1);

    // Reps 6 → aralık 180 günü aşar, madde "yanlışlarım" listesinden çıkar.
    await store.markResolvedSM2('q1', 5);
    expect(store.count, 0);
  });

  test(
    'SM-2 Zor (q = 3) daha yavaş ilerler ve 8 tekrarda mezun olur',
    () async {
      final store = await MistakeStore.load();

      await store.markMistake('q1');

      // Zor cevaplarda easeFactor düşer; aralık 180 güne ulaşmadan önce
      // tekrar sayısı eşiği (8) devreye girer.
      for (var i = 0; i < 7; i++) {
        await store.markResolvedSM2('q1', 3);
        expect(
          store.count,
          1,
          reason: '${i + 1}. tekrardan sonra madde silinmemeli',
        );
      }

      await store.markResolvedSM2('q1', 3);
      expect(store.count, 0);
    },
  );

  test('mezun olan maddenin SRS geçmişi silinmez', () async {
    final store = await MistakeStore.load();

    await store.markMistake('q1');
    for (var i = 0; i < 8; i++) {
      await store.markResolvedSM2('q1', 5);
    }
    expect(store.count, 0);

    // Aynı soru ileride tekrar yanlış cevaplanırsa easeFactor 2.5'ten
    // değil, kullanıcının gerçek geçmişinden devam etmeli. Geçmiş
    // silinseydi easeFactor 2.5 - 0.2 = 2.3 olurdu.
    await store.markMistake('q1');
    expect(store.count, 1);
    expect(store.easeFactorForTest('q1'), greaterThan(2.3));
  });

  test('daily history counts correct and wrong answers', () async {
    final store = await MistakeStore.load();

    await store.markMistake('q1'); // wrong +1
    await store.markResolved('q1'); // correct +1
    await store.markResolved(
      'q2',
    ); // correct +1 (even if q2 not a mistake, counted in history)

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
