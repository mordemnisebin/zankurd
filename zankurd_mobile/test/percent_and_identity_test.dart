import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/percent_format.dart';
import 'package:zankurd_mobile/src/utils/player_identity.dart';

/// 2026-07-25 canlı denetimi:
/// * Aynı ekranda `%0` (Türkçe önek) ve `0%` (sonek) yan yana görünüyordu;
///   üstelik önek biçimi Kurmancî arayüzde de kullanılıyordu.
/// * Ana ekran "ZanKurd", profil "Lîstikvanê ZanKurd" diyordu; avatar da
///   bu yüzden bir ekranda "Z", diğerinde "L" harfini gösteriyordu.
void main() {
  group('PercentFormat', () {
    test('Türkçede önek, Kurmancîde sonek kullanılır', () {
      expect(PercentFormat.value(42, isKu: false), '%42');
      expect(PercentFormat.value(42, isKu: true), '42%');
    });

    test('oran 0-100 aralığına kırpılır ve yuvarlanır', () {
      expect(PercentFormat.ratio(0.666, isKu: true), '67%');
      expect(PercentFormat.ratio(-1, isKu: true), '0%');
      expect(PercentFormat.ratio(5, isKu: false), '%100');
    });

    test('kaynakta elle yazılmış yüzde biçimi kalmadı', () {
      // Bu dosyalar denetimde iki farklı biçimi barındırıyordu.
      const files = [
        'lib/src/screens/home/home_rows.dart',
        'lib/src/screens/home/daily_missions_card.dart',
        'lib/src/widgets/kilim_progress_bar.dart',
        'lib/src/screens/quiz/quiz_option_tile.dart',
        'lib/src/screens/profile_screen.dart',
        'lib/src/widgets/share_result_card.dart',
      ];
      for (final path in files) {
        final source = File(path).readAsStringSync();
        const quote = "'";
        // Önek biçimi:  '%$...    Sonek biçimi:  ...}%'
        expect(
          source.contains('$quote%\$'),
          isFalse,
          reason: '$path içinde elle önek yüzde biçimi var',
        );
        expect(
          source.contains('}%$quote'),
          isFalse,
          reason: '$path içinde elle sonek yüzde biçimi var',
        );
      }
    });
  });

  group('PlayerIdentity', () {
    test('boş ve varsayılan adlar tek yedeğe düşer', () {
      for (final raw in [
        null,
        '',
        '   ',
        'ZanKurd',
        'ZanKurd Oyuncusu',
        'Lîstikvanê ZanKurd',
      ]) {
        expect(PlayerIdentity.resolveName(raw, isKu: false), 'Oyuncu');
        expect(PlayerIdentity.resolveName(raw, isKu: true), 'Lîstikvan');
      }
    });

    test('gerçek ad olduğu gibi korunur', () {
      expect(PlayerIdentity.resolveName('Berfin', isKu: true), 'Berfin');
      expect(
        PlayerIdentity.resolveName('  Berfin Aydın  ', isKu: false),
        'Berfin Aydın',
      );
    });

    test('kısa ad ilk kelimedir', () {
      expect(
        PlayerIdentity.resolveShortName('Berfin Aydın', isKu: false),
        'Berfin',
      );
      expect(PlayerIdentity.resolveShortName(null, isKu: true), 'Lîstikvan');
    });

    test('baş harf her zaman çözümlenmiş addan gelir', () {
      // Denetimdeki hata: ham "ZanKurd Oyuncusu" ana ekranda "Z", profilde
      // yerel yedek yüzünden "L" veriyordu.
      expect(
        PlayerIdentity.resolveInitial('ZanKurd Oyuncusu', isKu: true),
        'L',
      );
      expect(
        PlayerIdentity.resolveInitial('ZanKurd Oyuncusu', isKu: false),
        'O',
      );
      expect(PlayerIdentity.resolveInitial('berfin', isKu: true), 'B');
    });
  });
}
