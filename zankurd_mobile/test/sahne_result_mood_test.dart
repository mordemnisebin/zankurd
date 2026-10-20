/// Sonuç sahnesinin tonu doğruluğa göre değişir.
///
/// ## Kusur
///
/// 2/10 bitiren oyuncu da altın halesi, altın puanı ve "tamamlandı"
/// kutlamasıyla karşılanıyordu; rakiplerde düşük puanda sahne sakindir.
///
/// ## Niçin sessiz kalırdı
///
/// Sahne her sonuçta aynı widget ağacını çizer; eşik ya da hale ayrımı hiçbir
/// testin baktığı bir davranış değildi. Burada eşikler ve düşük tonda halenin
/// kalktığı, gradyanın sakinleştiği sabitlenir.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  test('eşikler: >=70 yüksek, 40-69 orta, <40 düşük', () {
    expect(SahneResultMood.fromAccuracy(100), SahneResultMood.high);
    expect(SahneResultMood.fromAccuracy(70), SahneResultMood.high);
    expect(SahneResultMood.fromAccuracy(69), SahneResultMood.mid);
    expect(SahneResultMood.fromAccuracy(40), SahneResultMood.mid);
    expect(SahneResultMood.fromAccuracy(39), SahneResultMood.low);
    expect(SahneResultMood.fromAccuracy(20), SahneResultMood.low);
  });

  test('düşük tonda hale yok ve gradyan sakin; yüksekte tam sahne', () {
    const child = SizedBox.shrink();
    const high = SahneResultScene(
      accent: SahneRole.learn,
      night: false,
      child: child,
    );
    const low = SahneResultScene(
      accent: SahneRole.learn,
      night: false,
      mood: SahneResultMood.low,
      child: child,
    );
    expect(high.glow, isNotNull);
    expect(low.glow, isNull);
    expect(high.colors, SahneVivid.learnSceneDay);
    // Üst durak tabana yaklaşır (daha sakin), taban aynı kalır.
    expect(low.colors.first, isNot(high.colors.first));
    expect(low.colors.last, high.colors.last);
  });
}
