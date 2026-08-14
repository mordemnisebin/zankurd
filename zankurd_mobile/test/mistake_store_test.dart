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

  // 2026-07-31 denetim bulgusu: `markResolvedSM2` önce `_recordAnswer(true)`
  // ile bugünün doğru sayacını BELLEKTE artırıyor, hemen ardından madde
  // yanlışlar defterinde değilse `_persist()` çağırmadan çıkıyordu.
  //
  // Normal quizde doğru cevaplanan soruların neredeyse tamamı o dala
  // düşer, yani doğru cevap sayacı diske hiç yazılmıyordu. Profildeki
  // "Cevaplanan Soru", "Doğruluk" ve haftalık grafik uygulama yeniden
  // açıldığında yalnız yanlışları hatırlıyordu.
  //
  // Kusur sessizdi çünkü aynı oturumda her şey doğru görünüyor; yalnız
  // yeniden açılışta ortaya çıkıyor. Bekçi de tam onu ölçer.
  test('doğru cevaplar yeniden açılışta korunur', () async {
    final store = await MistakeStore.load();

    // Defterde olmayan sorular — yani normal bir turun tipik hâli.
    await store.markResolved('yeni-1');
    await store.markResolved('yeni-2');
    await store.markResolved('yeni-3');

    expect(store.totalCorrect, 3);
    expect(store.totalWrong, 0);

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load();

    expect(
      restored.totalCorrect,
      3,
      reason: 'Doğru cevap sayacı yalnız bellekte yaşıyor, diske yazılmıyor.',
    );
    expect(restored.accuracyPercent, 100);
  });

  test('hiç yanlış yapmayan oyuncunun doğruluğu boş kalmaz', () async {
    final store = await MistakeStore.load();
    await store.markResolved('yalniz-dogru');

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load();

    // Kusurlu hâlde burası null dönüyordu: profil "Doğruluk: —" gösteriyordu.
    expect(restored.accuracyPercent, isNotNull);
    expect(restored.totalCorrect, greaterThan(0));
  });

  // 2026-08-14 denetim bulgusu: `_recordAnswer` her yeni cevaptan sonra
  // _history map'inden 7 günden eski GÜNLERİ siliyordu. `totalCorrect`/
  // `totalWrong`/`accuracyPercent` bu map'in TAMAMI üzerinden toplandığı
  // ve profilde "tüm zamanların toplamı" olarak gösterildiği için, eski
  // günler her hafta sessizce düşüyor ve kullanıcı aylarca oynasa bile
  // "Cevaplanan Soru" karosu yalnız son 7 günü gösteriyordu. Bekçi, 7
  // günden eski bir günün diskten yüklendikten sonra bile toplamlara
  // dahil kaldığını doğrular.
  test('7 günden eski günler tüm-zamanlar toplamından silinmez', () async {
    final store = await MistakeStore.load();

    // Doğrudan private _history yerine gerçek genel API üzerinden bugüne
    // birkaç cevap yazdırıp, eski bir günü SharedPreferences'a elle
    // enjekte ediyoruz — bu, "uygulama haftalar sonra tekrar açıldı"
    // senaryosunu temsil eder.
    await store.markResolved('bugun-1');
    expect(store.totalCorrect, 1);

    final prefs = await SharedPreferences.getInstance();
    final oldDay = DateTime.now().subtract(const Duration(days: 30));
    final oldKey =
        '${oldDay.year.toString().padLeft(4, '0')}-'
        '${oldDay.month.toString().padLeft(2, '0')}-'
        '${oldDay.day.toString().padLeft(2, '0')}';
    await prefs.setString(
      'zankurd.dailyPerformance',
      '{"$oldKey":{"correct":5,"wrong":2}}',
    );

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load();
    expect(
      restored.totalCorrect,
      5,
      reason: '30 gün önceki gün, diskten yüklendiğinde toplama dahil olmalı',
    );

    // Yeni bir cevap kaydetmek (eski hatalı davranışta tam burada tetiklenen
    // budama adımı) 30 gün önceki günü SİLMEMELİ.
    await restored.markResolved('bugun-2');
    expect(
      restored.totalCorrect,
      6,
      reason:
          '30 günlük gün, yeni bir cevap kaydedilirken sessizce silinmemeli',
    );

    // Haftalık grafik yine de yalnız son 7 günü döndürür — 30 gün önceki
    // gün orada görünmemeli, ama toplamlarda kaybolmamalı.
    final weekly = restored.getLast7DaysHistory();
    expect(weekly.containsKey(oldKey), isFalse);
  });

  test('karışık turda doğruluk oranı gerçek değeri verir', () async {
    final store = await MistakeStore.load();
    await store.markResolved('d1');
    await store.markResolved('d2');
    await store.markResolved('d3');
    await store.markMistake('y1');

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load();

    // Kusurlu hâlde yalnız yanlış kalıcı olduğu için oran %0 görünüyordu.
    expect(restored.totalCorrect, 3);
    expect(restored.totalWrong, 1);
    expect(restored.accuracyPercent, 75);
  });
}
