// Bekçi: saat geri alınınca / saat dilimi batıya kayınca seri bozulmaz (B4).
//
// ## Kusur
// `StreakStore` `lastDay`i yalnız "bugün" ya da "dün" ile karşılaştırıyordu.
// Cihaz saati geri alınırsa (elle, ya da batıya seyahatle saat dilimi
// değişince) kayıtlı `lastDay` GELECEKTE kalır: `effectiveStreak` 0 döner ve
// `recordPlay` seriyi 1'e sıfırlardı. Oysa oyuncu hiçbir gün atlamamıştı.
//
// ## Niçin sessiz kalırdı
// Tüm testler `now`u hep ileri sarıyordu; geri giden bir saat hiç denenmedi.
// Kullanıcı yalnız "serim nedense sıfırlandı" diye yakınırdı, log yoktu.
//
// ## Kural
// Gelecekteki `lastDay` "bugün" sayılır: seri korunur, `recordPlay`
// sıfırlamaz ve `lastDay` ASLA geriye taşınmaz (geçmiş/eşit günde artış yok).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakStore.resetInstance();
  });

  Future<StreakStore> storeWithStreakEndingOn20th() async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 18));
    await store.recordPlay(now: DateTime(2026, 6, 19));
    await store.recordPlay(now: DateTime(2026, 6, 20));
    return store;
  }

  test('lastDay gelecekteyse effectiveStreak 0 olmaz', () async {
    final store = await storeWithStreakEndingOn20th();
    // Saat 2 gün geri alındı: bugün 18, lastDay 20.
    expect(store.effectiveStreak(now: DateTime(2026, 6, 18, 9)), 3);
  });

  test('lastDay gelecekteyken willBreakOnPlay false', () async {
    final store = await storeWithStreakEndingOn20th();
    expect(store.willBreakOnPlay(now: DateTime(2026, 6, 18, 9)), isFalse);
  });

  test('lastDay gelecekteyken recordPlay seriyi sıfırlamaz', () async {
    final store = await storeWithStreakEndingOn20th();
    final streak = await store.recordPlay(now: DateTime(2026, 6, 18, 9));
    expect(streak, 3);
    expect(store.best, 3);
  });

  test(
    'geri alınmış günde lastDay geriye taşınmaz; saat düzelince devam eder',
    () async {
      final store = await storeWithStreakEndingOn20th();
      await store.recordPlay(now: DateTime(2026, 6, 18, 9));
      expect(store.lastDay, '2026-06-20', reason: 'lastDay asla geri gitmez');
      // Hâlâ geçmiş/eşit günler: artış yok.
      expect(await store.recordPlay(now: DateTime(2026, 6, 19, 9)), 3);
      expect(await store.recordPlay(now: DateTime(2026, 6, 20, 9)), 3);
      // lastDay'in ertesi günü dünün devamıdır.
      expect(await store.recordPlay(now: DateTime(2026, 6, 21, 9)), 4);
    },
  );

  test('24→23→24 aynı gerçek günde seri iki kez artmaz', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 22, 12));
    await store.recordPlay(now: DateTime(2026, 6, 23, 12));
    expect(await store.recordPlay(now: DateTime(2026, 6, 24, 12)), 3);
    expect(await store.recordPlay(now: DateTime(2026, 6, 23, 18)), 3);
    expect(await store.recordPlay(now: DateTime(2026, 6, 24, 18)), 3);
  });

  test('24→22→24 seriyi kırmaz', () async {
    final store = await StreakStore.load();
    await store.recordPlay(now: DateTime(2026, 6, 23, 12));
    expect(await store.recordPlay(now: DateTime(2026, 6, 24, 12)), 2);
    expect(await store.recordPlay(now: DateTime(2026, 6, 22, 12)), 2);
    expect(await store.recordPlay(now: DateTime(2026, 6, 24, 20)), 2);
  });
}
