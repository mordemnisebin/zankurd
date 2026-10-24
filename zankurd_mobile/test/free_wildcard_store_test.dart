import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/free_wildcard_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';

/// Günlük bedava joker hakkı.
///
/// ## Kusur
///
/// Yeni oyuncunun jetonu 8–19 iken jokerler 20–50 jeton ediyordu: ilk
/// günlerde joker HİÇ kullanılamıyor, joker satırı her soruda "Joker için
/// jeton yetmiyor" diyen kilitli bir çubuğa iniyordu. Özellik var ama
/// ulaşılamazdı; oyuncu ne işe yaradığını hiç deneyemiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Fiyat sözleşmesi (`wildcard_price_contract_test`) tutarı sınar, "yeni
/// oyuncu bir jokeri deneyebilir mi" sorusunu kimse sormuyordu; kilit
/// tasarımın bir parçası sanılıyordu.
///
/// ## Kural
///
/// Her kullanıcıya, yerel günde bir kez, jetonsuz bir joker. Hak kullanıcıya
/// bağlıdır (`LocalProgressScope`): bir hesabın hakkı ötekine geçmez, hesap
/// değişince geri gelmez. Sunucu jeton mantığı değişmez; bedava kullanımda
/// `spend_coins` hiç çağrılmaz.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });
  tearDown(LocalProgressScope.debugReset);

  final noon = DateTime(2026, 10, 24, 12);

  test('günün ilk kullanımı bedava: hak var, tüketince biter', () async {
    expect(await FreeWildcardStore.isAvailable(now: noon), isTrue);
    expect(await FreeWildcardStore.consume(now: noon), isTrue);
    expect(await FreeWildcardStore.isAvailable(now: noon), isFalse);
  });

  test('ikinci kullanım bedava değil: tüketme false döner', () async {
    expect(await FreeWildcardStore.consume(now: noon), isTrue);
    expect(await FreeWildcardStore.consume(now: noon), isFalse);
    // Aynı günün akşamı da aynı gündür.
    final evening = DateTime(2026, 10, 24, 23, 59);
    expect(await FreeWildcardStore.isAvailable(now: evening), isFalse);
  });

  test('yeni gün hakkı yeniler (gece yarısı yerel saate göre)', () async {
    await FreeWildcardStore.consume(now: DateTime(2026, 10, 24, 23, 59));
    expect(
      await FreeWildcardStore.isAvailable(now: DateTime(2026, 10, 25, 0, 1)),
      isTrue,
    );
    expect(
      await FreeWildcardStore.consume(now: DateTime(2026, 10, 25, 0, 1)),
      isTrue,
    );
  });

  test(
    'hak kullanıcıya bağlı: ötekinin tükettiği seninkini bitirmez',
    () async {
      LocalProgressScope.bind('user-a');
      expect(await FreeWildcardStore.consume(now: noon), isTrue);
      expect(await FreeWildcardStore.isAvailable(now: noon), isFalse);

      LocalProgressScope.bind('user-b');
      expect(await FreeWildcardStore.isAvailable(now: noon), isTrue);
      expect(await FreeWildcardStore.consume(now: noon), isTrue);

      // A'ya dönünce hâlâ tükenmiş: hesap değiştirmek hakkı geri getirmez.
      LocalProgressScope.bind('user-a');
      expect(await FreeWildcardStore.isAvailable(now: noon), isFalse);
    },
  );
}
