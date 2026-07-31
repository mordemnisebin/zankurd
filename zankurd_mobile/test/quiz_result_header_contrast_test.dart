import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 1v1 sonuç başlığı her üç sonuçta da okunur.
///
/// ## Kusur
///
/// Başlığın içeriği (sonuç adı, skor, doğruluk, sayaçlar) sabit
/// `Colors.white` ile çiziliyor. Kazanan ve kaybeden gradyanları
/// tema-bağımsız KOYU tonlar: `correct → correctDeep`,
/// `wrong → wrongDeep`. Berabere gradyanı ise `surfaceHiColor(context)` ve
/// `surfaceColor(context)` idi — TEMAYA GÖRE değişen yüzey tonları. Açık
/// temada ikisi de neredeyse beyaz, dolayısıyla beyaz metin beyaz zeminde
/// kayboluyordu.
///
/// Kusur ancak iki oyuncu AYNI skorla bitirdiğinde doğuyor: ne kod
/// okumasında ne tek kişilik turda görünüyor. 2026-08-01'de canlı bir oda
/// maçı 0-0 bitince görüldü — yıldızlar, "0" ve "Ziman · %0 rastbûn"
/// beyaz kartın üstünde silik hayaletlerdi.
///
/// ## Bekçi niçin böyle
///
/// Ekranı render etmek RevenueCat/repository kurulumu istiyor ve gradyan
/// zaten saf renk sabitlerinden kuruluyor. Bu yüzden bekçi iki iş yapıyor:
/// (1) üç sonucun kullandığı tonları SAYIYLA ölçer, (2) berabere dalının
/// temaya bağlı yüzey yardımcılarına geri dönmediğini doğrular — asıl
/// kusur oradaydı.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Üç sonucun gradyan uçları. Hepsi tema-bağımsız sabitler olmalı:
  // başlık içeriği sabit beyazdır, yani zemin iki temada da koyu kalmalı.
  const outcomes = <String, List<Color>>{
    'kazandı': [AppTheme.correctHeader, AppTheme.correctDeep],
    'kaybetti': [AppTheme.wrongHeader, AppTheme.wrongDeep],
    'berabere': [AppTheme.surfaceHi, AppTheme.surface],
  };

  outcomes.forEach((outcome, colors) {
    test('$outcome başlığı beyaz metni okutuyor', () {
      for (final color in colors) {
        expect(
          _contrast(Colors.white, color),
          greaterThanOrEqualTo(4.5),
          reason:
              '$outcome gradyanının bir ucu ($color) beyaz metni okutmuyor. '
              'Başlık içeriği sabit beyazdır; zemin koyu kalmak zorunda.',
        );
      }
    });
  });

  test('berabere dalı temaya bağlı yüzey tonuna geri dönmemiş', () {
    // Asıl kusur buydu: `surfaceHiColor(context)` açık temada neredeyse
    // beyaz. Sayısal kontrol tek başına yetmez çünkü ekran o yardımcıya
    // dönerse sabitler yine geçer ama gerçek zemin değişir.
    final source = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    final drawBranch = source.substring(
      source.indexOf(': isDraw'),
      source.indexOf('final borderColor'),
    );
    final code = drawBranch
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code,
      isNot(contains('surfaceHiColor(context)')),
      reason:
          'Berabere gradyanı temaya göre açılırsa beyaz başlık yine '
          'kaybolur.',
    );
    expect(
      code,
      isNot(contains('surfaceColor(context)')),
      reason: 'Aynı sebeple.',
    );
    expect(
      code,
      contains('AppTheme.surfaceHi, AppTheme.surface'),
      reason: 'Berabere, tema-bağımsız koyu nötr tonu kullanmalı.',
    );
  });

  test('üç sonuç birbirinden ayırt edilebiliyor', () {
    // Hepsini koyulaştırmak okunurluğu çözer ama bilgiyi siler: oyuncu
    // kazandığını, kaybettiğini ve berabere kaldığını renkten anlamalı.
    final pairs = outcomes.values.toList();
    for (var i = 0; i < pairs.length; i++) {
      for (var j = i + 1; j < pairs.length; j++) {
        expect(
          pairs[i].first,
          isNot(pairs[j].first),
          reason: 'İki sonuç aynı gradyanı taşıyor.',
        );
      }
    }
  });
}
