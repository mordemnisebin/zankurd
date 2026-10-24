// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
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

  test('eşzamanlı load çağrıları aynı singleton örneğini paylaşır', () async {
    final firstLoad = MistakeStore.load();
    final secondLoad = MistakeStore.load();
    final thirdLoad = MistakeStore.load();

    final stores = await Future.wait([firstLoad, secondLoad, thirdLoad]);
    expect(identical(stores[0], stores[1]), isTrue);
    expect(identical(stores[0], stores[2]), isTrue);
  });

  // 2026-07-25 denetim bulgusu: eski mezuniyet eşiği maddeyi 3-4 doğru
  // cevaptan sonra sistemden tamamen siliyordu. 2026-10-24: mezuniyet YALNIZ
  // ayrı oturum sayısına bağlıdır (iki oturum); eski tekrar sayısı / aralık
  // eşikleri kalktı, çünkü aynı oturumda yeterince doğru cevap soruyu
  // gerçek hatırlama kanıtı olmadan çıkarıyordu. SM-2 yalnız ZAMANLAR.
  test('aynı oturumda kaç doğru olursa olsun madde kuyruktan çıkmaz', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1');
    for (var i = 0; i < 12; i++) {
      await store.markResolvedSM2('q1', 5, sessionId: 'tek');
      expect(store.count, 1, reason: '${i + 1}. doğru, hep aynı oturum');
    }
    for (var i = 0; i < 12; i++) {
      await store.markResolvedSM2('q1', 3, sessionId: 'tek');
      expect(store.count, 1, reason: 'Zor ${i + 1}, hep aynı oturum');
    }
    await store.markResolvedSM2('q1', 3, sessionId: 'ikinci');
    expect(store.count, 0);
  });

  test('mezun olan maddenin SRS geçmişi silinmez', () async {
    final store = await MistakeStore.load();

    await store.markMistake('q1'); // easeFactor 2.3
    await store.markMistake('q1'); // 2.1
    await store.markResolvedSM2('q1', 5, sessionId: 'a');
    await store.markResolvedSM2('q1', 5, sessionId: 'b');
    expect(store.count, 0);

    // Aynı soru ileride tekrar yanlış cevaplanırsa easeFactor 2.5'ten değil,
    // kullanıcının gerçek geçmişinden devam etmeli (geçmiş silinseydi 2.3).
    await store.markMistake('q1');
    expect(store.count, 1);
    expect(store.easeFactorForTest('q1'), closeTo(2.1, 0.001));
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

  test(
    'hazır tekrarları kategori bazında yalnız zamanı gelenlerden sayar',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': [
          'ready-ziman',
          'later-ziman',
          'ready-dirok',
        ],
        'zankurd.mistakeMetadata':
            '{"ready-ziman":{"nextReview":${now - 1000},"category":"Ziman"},'
            '"later-ziman":{"nextReview":${now + 86400000},"category":"Ziman"},'
            '"ready-dirok":{"nextReview":${now - 1000},"category":"Dîrok"}}',
      });
      MistakeStore.resetInstance();

      final store = await MistakeStore.load();
      final counts = store.getReadyReviewCountByCategory();
      final playableCounts = store.getReadyReviewCountByCategory(
        allowedQuestionIds: {'ready-ziman'},
      );

      expect(counts, {'Ziman': 1, 'Dîrok': 1});
      expect(playableCounts, {'Ziman': 1});
    },
  );

  // 2026-07-31 denetim bulgusu: `markResolvedSM2` önce `_recordAnswer(true)`
  // ile bugünün doğru sayacını BELLEKTE artırıyor, hemen ardından madde
  // yanlışlar defterinde değilse `_persist()` çağırmadan çıkıyordu.
  //
  // Normal quizde doğru cevaplanan soruların neredeyse tamamı o dala
  // düşer, yani doğru cevap sayacı diske hiç yazılmıyordu. Profildeki
  // "Cevaplanan soru", "Doğruluk" ve haftalık grafik uygulama yeniden
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
  // "Cevaplanan soru" karosu yalnız son 7 günü gösteriyordu. Bekçi, 7
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

  test('works with injected LocalDataStorage implementation', () async {
    final storage = InMemoryDataStorage();
    final store = await MistakeStore.load(storage: storage);

    await store.markMistake('m1');
    await store.markResolved('d1');

    expect(store.count, 1);
    expect(store.contains('m1'), isTrue);
    expect(storage.getStringList('zankurd.mistakeQuestionIds'), ['m1']);

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load(storage: storage);
    expect(restored.count, 1);
    expect(restored.contains('m1'), isTrue);
    expect(restored.totalCorrect, 1);
    expect(restored.totalWrong, 1);
  });

  group('tekrar kuyruğu: iki ayrı oturumda doğru -> kuyruktan çıkar', () {
    // ## Kusur
    //
    // Yanlış cevaplanan soru ancak 6-8 doğru tekrar (ya da 180 günlük aralık)
    // sonra kuyruktan çıkıyordu; kullanıcı iki kez doğru yaptığı soruyu
    // haftalarca "tekrar edilecek" listesinde görüyordu.
    //
    // ## Niçin sessiz kalırdı
    //
    // Soru kuyrukta kaldıkça hiçbir hata görünmez; yalnız rozet şişer.
    //
    // ## Kural
    //
    // Soru, FARKLI iki oturumda doğru cevaplanınca çıkar. Aynı oturumdaki
    // ikinci doğru sayılmaz; yanlış cevap sayacı sıfırlar.
    test('iki ayrı oturumdaki doğru cevap soruyu kuyruktan çıkarır', () async {
      final store = await MistakeStore.load();
      await store.markMistake('q1');
      expect(store.queueCount, 1);

      await store.markResolved('q1', sessionId: 'oturum-1');
      expect(store.contains('q1'), isTrue, reason: 'tek doğru yetmez');

      await store.markResolved('q1', sessionId: 'oturum-2');
      expect(store.contains('q1'), isFalse);
      expect(store.queueCount, 0);
    });

    test('aynı oturumdaki ikinci doğru cevap sayılmaz', () async {
      final store = await MistakeStore.load();
      await store.markMistake('q1');
      await store.markResolved('q1', sessionId: 'oturum-1');
      await store.markResolved('q1', sessionId: 'oturum-1');
      expect(store.contains('q1'), isTrue);

      await store.markResolved('q1', sessionId: 'oturum-2');
      expect(store.contains('q1'), isFalse);
    });

    test('araya giren yanlış cevap sayacı sıfırlar', () async {
      final store = await MistakeStore.load();
      await store.markMistake('q1');
      await store.markResolved('q1', sessionId: 'oturum-1');
      await store.markMistake('q1');
      await store.markResolved('q1', sessionId: 'oturum-2');
      expect(store.contains('q1'), isTrue, reason: 'sayaç sıfırlanmıştı');

      await store.markResolved('q1', sessionId: 'oturum-3');
      expect(store.contains('q1'), isFalse);
    });

    test('oturum kimliği verilmezse her çağrı ayrı oturumdur', () async {
      final store = await MistakeStore.load();
      await store.markMistake('q1');
      await store.markResolved('q1');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await store.markResolved('q1');
      expect(store.contains('q1'), isFalse);
    });

    test('sayaç uygulama yeniden açılınca korunur', () async {
      final store = await MistakeStore.load();
      await store.markMistake('q1');
      await store.markResolved('q1', sessionId: 'oturum-1');

      MistakeStore.resetInstance();
      final restored = await MistakeStore.load();
      expect(restored.contains('q1'), isTrue);
      await restored.markResolved('q1', sessionId: 'oturum-2');
      expect(restored.contains('q1'), isFalse);
    });
  });

  group('tekrar kuyruğu: öncelik sırası', () {
    test('en eski gecikme önce, eşitse en çok kaçırılan önce', () async {
      final storage = InMemoryDataStorage();
      final now = DateTime.now().millisecondsSinceEpoch;
      const day = 24 * 60 * 60 * 1000;
      // Kapsam bağlı değil: fiziksel anahtar mantıksal adın kendisidir.
      await storage.setStringList('zankurd.mistakeQuestionIds', [
        'yeni-az',
        'yeni-cok',
        'eski',
      ]);
      await storage.setString(
        'zankurd.mistakeMetadata',
        '{"yeni-az":{"nextReview":${now - 2 * day - 1000},"missCount":1},'
            '"yeni-cok":{"nextReview":${now - 2 * day - 500},"missCount":4},'
            '"eski":{"nextReview":${now - 9 * day},"missCount":1}}',
      );
      final store = await MistakeStore.load(storage: storage);
      expect(store.readyIdsMostOverdueFirst, ['eski', 'yeni-cok', 'yeni-az']);
    });

    test('kaçırma sayısı yanlışla birikir ve mezuniyette korunur', () async {
      final store = await MistakeStore.load();
      await store.markMistake('q1');
      await store.markMistake('q1');
      await store.markResolved('q1', sessionId: 'a');
      await store.markResolved('q1', sessionId: 'b');
      expect(store.contains('q1'), isFalse);
      await store.markMistake('q1');
      expect(store.contains('q1'), isTrue);
      expect(store.missCountForTest('q1'), 3);
    });
  });
}
