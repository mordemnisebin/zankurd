// 2026-10-20 TASARIM KURULU (tur 6b): koyu temada kart zeminden ayrılır.
//
// ## Kusur
//
// Koyu temada (ana sayfa, oyun merkezi, profil) kart yüzeyi Perde #1C1D21,
// zemin Şev #121214'tü: aradaki oran 1,13:1 ve 1 px kenar #34363C yüzeye
// çok yakındı; kartlar zemine gömülüyordu (2 denetçi).
//
// ## Niçin sessiz kalırdı
//
// Renk çiftleri tek tek "geçerli" renklerdi; metin kontrastı bekçileri
// (contrast_policy, sahne_palette) YÜZEY ÜSTÜ METNİ ölçer, yüzeyin zeminden
// ayrılıp ayrılmadığını değil. Bu dosya o oranı ölçer: yüzey/zemin >= 1,15,
// kenar/zemin >= 1,6, katman sırası zemin < Perde < Kulis < Ray; zemin
// grafit kimliğiyle #121214 kalır; AppTheme sabitleri belirteçlerle aynıdır.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  const n = SahneTokens.night;

  test('zemin grafit #121214 kalır', () {
    expect(n.bg, const Color(0xFF121214));
    expect(AppTheme.bg, const Color(0xFF121214));
  });

  test('kart yüzeyi zeminden ayrılır; 1 px kenar belirgin', () {
    expect(_ratio(n.s1, n.bg), greaterThanOrEqualTo(1.15));
    expect(_ratio(n.edge, n.bg), greaterThanOrEqualTo(1.6));
  });

  test('katman sırası: zemin < Perde < Kulis < Ray', () {
    expect(n.bg.computeLuminance(), lessThan(n.s1.computeLuminance()));
    expect(n.s1.computeLuminance(), lessThan(n.s2.computeLuminance()));
    expect(n.s2.computeLuminance(), lessThan(n.s3.computeLuminance()));
  });

  test('AppTheme gece sabitleri belirteçlerle aynı', () {
    expect(AppTheme.surface, n.s1);
    expect(AppTheme.surfaceHi, n.s2);
    expect(AppTheme.border, n.edge);
  });
}
