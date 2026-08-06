import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Çeldirici kendini yanlış ilan etmemeli.
///
/// ## Kusur
///
/// 2026-08-06'da dış model havuzları incelenirken Grok'un 407 adayının
/// **296'sı (%72,7)** şıklarında kendi yanlışlığını duyuruyordu:
///
///     ["512 KB (yanlış)", ...]
///     ["RAM (ne rast) (ne rastîn)", "RAM (yanlış) (geçersiz)"]
///
/// Oyuncu konuyu hiç bilmeden etiketsiz şıkkı seçer ve kazanır. Soru sınav
/// olmaktan çıkar.
///
/// Bunu iki kapı birden kaçırmıştı. `validate_batch.py`'nin `answer-leak-*`
/// kuralı yalnız doğru cevabın SORU KÖKÜNDE geçmesine bakıyordu; buradaki
/// sızıntı şıkkın kendi içindeydi. Sekiz batch'in sekizine de PASS verilmişti.
/// Üretici modelin kendi raporu da 407'yi "ön elemeden geçti" sayıyordu.
///
/// Ders: bir kural "cevap sızdı mı" diye sorarken sızıntının nereden
/// geleceğini varsayarsa, varsaymadığı kanaldan geleni görmez.
///
/// Bu bekçi kuralı üretim bankalarına bağlar: dış havuzdan ya da elle,
/// böyle bir şık runtime'a giremez.
void main() {
  final banks = <String, List<Map<String, dynamic>>>{};

  setUpAll(() {
    for (final asset in questionBankAssets) {
      banks[asset] = (jsonDecode(File(asset).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
    }
  });

  /// `validate_batch.py`'deki `SELF_LABELED` ile aynı kapsam.
  final selfLabeled = RegExp(
    r'\(\s*(ne\s*rast(în)?|yanlış|yanlis|geçersiz|gecersiz|doğru\s*değil|'
    r'dogru\s*degil|not\s*correct|incorrect|false)\s*\)'
    r'|\s+(ne\s*rast(în)?|yanlış|geçersiz)\s*$',
    caseSensitive: false,
  );

  test('hiçbir şık kendi yanlışlığını duyurmuyor', () {
    final offenders = <String>[];
    banks.forEach((asset, rows) {
      for (final q in rows) {
        for (final field in ['answers', 'answersTr']) {
          final list = q[field];
          if (list is! List) continue;
          for (final option in list) {
            if (option is String && selfLabeled.hasMatch(option)) {
              offenders.add('${q['id']} ($asset) $field: "$option"');
            }
          }
        }
      }
    });
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu şıklar oyuncuya doğru cevabı bedava veriyor:\n'
          '${offenders.take(15).join("\n")}',
    );
  });

  test('bekçi gerçekten yakalıyor', () {
    // Kural yanlış yazılırsa üstteki test boş listeyle sessizce geçer.
    for (final sample in [
      '512 KB (yanlış)',
      'RAM (ne rast)',
      'Disk (geçersiz)',
      'Option (not correct)',
      'RAM e ne rast',
    ]) {
      expect(
        selfLabeled.hasMatch(sample),
        isTrue,
        reason: '"$sample" yakalanmalıydı',
      );
    }
    for (final clean in ['512 KB', 'RAM', 'Rojava', 'Amed (Diyarbakır)']) {
      expect(
        selfLabeled.hasMatch(clean),
        isFalse,
        reason: '"$clean" temiz sayılmalıydı',
      );
    }
  });
}
