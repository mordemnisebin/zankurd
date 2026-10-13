import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kurmancî'de `â` yoktur; "ziman" `a` ile yazılır, "Dersa rojê" ezafelidir.
///
/// ## Kusur
///
/// Mağaza metni taslağında "zimân" (Farsça/Osmanlıca etkili yazım) ve kod
/// yorumlarında "Dersê rojane" geçiyordu; ikisi de Kurmancî değil.
///
/// ## Niçin sessizdi
///
/// Dil bekçileri `strings.dart` anahtar defterini tarar; belge ve yorumlar
/// taranmaz. Mağaza metni kopyalanıp yayımlanırsa yanlış yazım kullanıcıya
/// ulaşırdı.
void main() {
  test('mağaza metninde "zimân" yok', () {
    final text = File('docs/store_listing.md').readAsStringSync();
    expect(text, isNot(contains('zimân')));
  });

  test('"Dersê rojane" yazımı kaynakta kalmadı', () {
    for (final path in [
      'lib/src/screens/home_screen.dart',
      'lib/src/data/daily_mission_store.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('Dersê rojane')),
        reason: path,
      );
    }
  });
}
