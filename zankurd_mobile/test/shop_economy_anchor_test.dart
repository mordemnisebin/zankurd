import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';

/// Mağaza fiyatları ölçülen gelire bağlı kalmalı.
///
/// ## Kusur
///
/// 2026-08-10 simülatör gezisi: yeni oyuncu mağazaya giriyor, dört ürün
/// görüyor, hiçbirini alamıyor ve yakın bir hedef de göremiyor.
///
/// Ölçüldüğünde sebep netti. Çevrimdışı oynayan bir oyuncunun TEK jeton
/// kaynağı günlük çarktır — solo tur sıfır jeton verir ve bu bir eksiklik
/// değil, `claim_quiz_reward` RPC'si `p_room_id is null` olduğunda
/// `verification_required` döner; sunucu doğrulayamadığı turu
/// ödüllendirmiyor. Çark günde ortalama 40,6 jeton veriyordu ve en ucuz
/// ürün 200 jetondu: ilk satın alma 4,9 gün, katalogun tamamı 24,6 gün.
///
/// ## Niçin bekçi
///
/// Fiyatlar sezgiyle değil ölçüyle konuldu; bekçi o ölçüyü koda bağlar ki
/// biri fiyatı değiştirdiğinde gerekçeyi de görsün.
///
/// En sert kısıt arbitrajdır ve testin asıl varlık sebebi odur:
/// `spin_wheel_extra` çarkın kendisini satıyor. Fiyatı çarkın AZAMİ ödülünün
/// altına inerse döngü kâr eder ve sınırsız jeton pompasına döner — üstelik
/// bu, bakiyeyi sunucunun tuttuğu üretimde gerçek bir ekonomi açığıdır.
void main() {
  const wheel = SpinWheelScreen.rewards;
  final maxSpin = wheel.reduce((a, b) => a > b ? a : b);
  final meanSpin = wheel.reduce((a, b) => a + b) / wheel.length;

  ShopItem itemById(String id) =>
      ShopItem.catalog.firstWhere((item) => item.id == id);

  test('ekstra çevirme çarkın azami ödülünden pahalı — arbitraj yok', () {
    final extraSpin = itemById('spin_wheel_extra');
    expect(
      extraSpin.cost,
      greaterThan(maxSpin),
      reason:
          'Ekstra çevirme ${extraSpin.cost} jeton ama çark en fazla $maxSpin '
          'veriyor. Fiyat azami ödülün altındaysa oyuncu çevirme alıp kâr '
          'ederek sınırsız jeton üretebilir.',
    );
  });

  test('ilk satın alma birkaç günlük çark geliriyle ulaşılabilir', () {
    final cheapest = ShopItem.catalog
        .map((item) => item.cost)
        .reduce((a, b) => a < b ? a : b);
    final days = cheapest / meanSpin;
    expect(
      days,
      lessThanOrEqualTo(4.0),
      reason:
          'En ucuz ürün $cheapest jeton; günlük ortalama çark geliri '
          '${meanSpin.toStringAsFixed(1)} jeton, yani ${days.toStringAsFixed(1)} '
          'gün. Yeni oyuncu ilk haftasında hiçbir şey alamazsa mağaza ve '
          'jeton döngüsü ölü yüzey olur.',
    );
  });

  test('katalog aspirasyonel ucunu koruyor', () {
    // Her şey ucuzlarsa döngü de anlamsızlaşır: pahalı ürün hedeftir.
    final priciest = ShopItem.catalog
        .map((item) => item.cost)
        .reduce((a, b) => a > b ? a : b);
    final days = priciest / meanSpin;
    expect(
      days,
      inInclusiveRange(12.0, 25.0),
      reason:
          'En pahalı ürün ${days.toStringAsFixed(1)} günlük gelir. Çok kısa '
          'olursa hedef kalmaz, çok uzun olursa ulaşılamaz görünür.',
    );
  });

  test('fiyatlar birbirinden ayrışıyor — katalog kademeli', () {
    final costs = ShopItem.catalog.map((item) => item.cost).toList()..sort();
    expect(
      costs.toSet(),
      hasLength(costs.length),
      reason: 'İki ürün aynı fiyattaysa kademe bilgisi vermiyor: $costs',
    );
  });
}
