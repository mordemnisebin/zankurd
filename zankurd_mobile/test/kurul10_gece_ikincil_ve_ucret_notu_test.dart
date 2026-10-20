// Kurul 9-10. tur (2026-10-20) iki bulgusunun bekçisi.
//
// 1. Gece ikincil/üçüncül yazı (ChatGPT + Grok + Codex): grafit kartlarda
//    tx2 #B9BAC0 ve tx3 #8F9199 sönük okunuyordu. AA (4.5:1) zaten geçtiği
//    için hiçbir kontrast bekçisi kırılmıyordu; kusur "geçer ama sönük"
//    olmaktı. Bekçi, Perde (s1) üstünde tx2 ≥ 8:1, tx3 ≥ 5.5:1 ve sıranın
//    (tx > tx2 > tx3) korunduğunu ister.
// 2. Özel oda ücret notu Kurmancîde ücretsizdi: TR "50 jeton için 40 jeton
//    eksik" derken KU yalnız "40 zêr kêm e" diyordu, çünkü ücret hazır bir
//    etiket olarak Türkçe sözcük sırasıyla birleştiriliyordu ve KU değeri
//    "-" yer tutucusuydu. KU şablonu kurulda (Grok 4.7 + Muse Spark) birebir
//    aynı çıktı: "Ji bo {fee} zêran {coins} zêr kêm in".
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

double _lum(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('gece tx2 ve tx3 Perde üstünde belirgin, sıra korunur', () {
    final night = SahneTokens.night;
    expect(_ratio(night.tx2, night.s1), greaterThanOrEqualTo(8.0));
    expect(_ratio(night.tx3, night.s1), greaterThanOrEqualTo(5.5));
    expect(_lum(night.tx), greaterThan(_lum(night.tx2)));
    expect(_lum(night.tx2), greaterThan(_lum(night.tx3)));
  });

  test('ücret notu iki dilde ücreti ve eksiği söyler', () {
    expect(
      Tr.of(K.coinsShortForFee, AppLanguage.tr, {'fee': '50', 'coins': '40'}),
      '50 jeton için 40 jeton eksik',
    );
    expect(
      Tr.of(K.coinsShortForFee, AppLanguage.ku, {'fee': '50', 'coins': '40'}),
      'Ji bo 50 zêran 40 zêr kêm in',
    );
  });
}
