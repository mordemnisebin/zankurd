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
// sıfırlamaz ve `lastDay` bugüne çekilir, böylece ertesi gün +1 devam eder.
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

  test('saat düzelince seri ertesi gün +1 devam eder', () async {
    final store = await storeWithStreakEndingOn20th();
    await store.recordPlay(now: DateTime(2026, 6, 18, 9));
    // lastDay bugüne (18) çekildi; ertesi gün (19) dünün devamıdır.
    final next = await store.recordPlay(now: DateTime(2026, 6, 19, 9));
    expect(next, 4);
  });
}
