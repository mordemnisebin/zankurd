// 2026-07-23 canlı UX denetimi M25b: aynı ekranda (leaderboard, oda/lobi
// listesi) render edilen oyuncular arasında hash çakışması varsa
// [resolveAvatarColors] round-robin ile farklı renk atar. Bu dosya saf
// mantığı (widget'tan bağımsız) izole test eder.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/avatar_presets.dart';

void main() {
  group('resolveAvatarColors', () {
    test('çakışan iki isim farklı renk alır', () {
      // "Diyar" ve "Newroz" avatarNamePalette'te aynı indekse hash'lenir
      // (bkz. avatarColorForName ile aynı 31-tabanlı hash).
      expect(avatarColorForName('Diyar'), avatarColorForName('Newroz'));

      final resolved = resolveAvatarColors([
        (id: 'p1', displayName: 'Diyar', colorHex: null),
        (id: 'p2', displayName: 'Newroz', colorHex: null),
      ]);

      expect(resolved['p1'], isNot(resolved['p2']));
      expect(resolved['p1'], avatarColorForName('Diyar'));
    });

    test('çakışmayan isimler kendi hash renklerini korur', () {
      final resolved = resolveAvatarColors([
        (id: 'p1', displayName: 'Azad', colorHex: null),
        (id: 'p2', displayName: 'Kejo', colorHex: null),
      ]);

      expect(resolved['p1'], avatarColorForName('Azad'));
      expect(resolved['p2'], avatarColorForName('Kejo'));
    });

    test('colorHex seçmiş oyuncular sonuç haritasında yer almaz', () {
      final resolved = resolveAvatarColors([
        (id: 'p1', displayName: 'Diyar', colorHex: '#123456'),
        (id: 'p2', displayName: 'Newroz', colorHex: null),
      ]);

      expect(resolved.containsKey('p1'), isFalse);
      expect(resolved['p2'], avatarColorForName('Newroz'));
    });

    test('aynı girdiyle her çağrıda deterministik sonuç üretir', () {
      List<({String id, String? displayName, String? colorHex})> entries() => [
        (id: 'p1', displayName: 'Diyar', colorHex: null),
        (id: 'p2', displayName: 'Newroz', colorHex: null),
        (id: 'p3', displayName: 'Sara', colorHex: null),
      ];

      final first = resolveAvatarColors(entries());
      final second = resolveAvatarColors(entries());
      expect(first, second);
      // Üç ismin de aynı hash dilimine düştüğü (bkz. Python doğrulaması)
      // — üçü de farklı renk almalı.
      expect({first['p1'], first['p2'], first['p3']}.length, 3);
    });

    test('palet boyutunu aşan girdi sayısında döngüye girmez', () {
      final entries = List.generate(
        avatarNamePalette.length + 5,
        (i) => (id: 'p$i', displayName: 'İsim$i', colorHex: null),
      );
      final resolved = resolveAvatarColors(entries);
      expect(resolved.length, entries.length);
      for (final color in resolved.values) {
        expect(avatarNamePalette, contains(color));
      }
    });
  });
}
