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
      // 2026-07-27: bu bekçi elle sayılmış altı dosyaya bakıyordu ve tam
      // da bu yüzden üç yeni kaçağı görmedi — öğrenme ekranı, sonuç
      // ekranı ve paylaşım metni Kurmancî arayüzde "%0" yazıyordu.
      // Listeye yenisi eklenmeyi unutulabilir; ağaç unutulamaz, o yüzden
      // tarama artık `lib/src`in tamamını gezer.
      const quote = "'";
      final offenders = <String>[];
      for (final entity in Directory('lib/src').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Biçimlendiricinin kendisi iki biçimi de içermek zorunda.
        if (entity.path.endsWith('utils/percent_format.dart')) continue;
        final source = entity.readAsStringSync();
        // Önek biçimi:  '%$...    Sonek biçimi:  ...}%'
        if (source.contains('$quote%\$') || source.contains('}%$quote')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'elle yazılmış yüzde biçimi: ${offenders.join(", ")}',
      );
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
