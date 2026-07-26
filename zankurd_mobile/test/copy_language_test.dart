import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Kurmancî terim tutarlılığı.
///
/// Bu test önce ekran kaynaklarını grep'liyordu (`ku ? 'Kûpa' : ...`).
/// Metinler anahtar tabanlı kayda taşınınca (2026-07-25 i18n göçü) kaynak
/// artık metni içermiyor; kontrol de doğru yere, yani tek doğruluk kaynağı
/// olan [Tr] defterine taşındı. Henüz göç etmemiş ekranlar için kaynak
/// kontrolü sürüyor.
void main() {
  test('turnuva terimi Kurmancî\'de "Kûpa" olarak kalır', () {
    // Türkçe "Turnuva" sözcüğü Kurmancî metne sızmamalı; karşılığı Kûpa.
    expect(Tr.of(K.tournament, AppLanguage.ku), 'Kûpa');
    expect(Tr.of(K.tournament, AppLanguage.tr), 'Turnuva Modu');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        kurmanci.toLowerCase(),
        isNot(contains('turnuva')),
        reason: '$key: Kurmancî metinde Türkçe "turnuva" geçiyor',
      );
    }
  });

  test('arkadaş durumu terimleri kayıt defterinde korunuyor', () {
    // Bu kontroller de `friends_screen.dart` kaynağını grep'liyordu;
    // ekran göç edince (2026-07-25) metin kaynakta kalmadı. Terimler artık
    // tek doğruluk kaynağından doğrulanır.
    expect(Tr.of(K.online, AppLanguage.ku), 'Serhêl');
    expect(Tr.of(K.online, AppLanguage.tr), 'Çevrimiçi');
    expect(Tr.of(K.offline, AppLanguage.ku), 'Ne li serhêl');
    expect(Tr.of(K.offline, AppLanguage.tr), 'Çevrimdışı');
    expect(Tr.of(K.roomCreateFailed, AppLanguage.ku), 'Jûr nehat avakirin');
  });

  test('göç etmemiş ekranlarda terim sözlüğü korunuyor', () {
    final shell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    final onboarding = File(
      'lib/src/screens/onboarding_screen.dart',
    ).readAsStringSync();

    expect(shell, isNot(contains('hevalên te, Turnuva')));
    expect(onboarding, isNot(contains("ku ? 'Turnuva")));
  });
}
