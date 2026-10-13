/// Bileşen kütüphanesiyle `sahne.dart`a eklenen belirteçlerin bekçisi.
///
/// ## Neyi korur
///
/// * `onOk`: dolu Rast elmasın üstündeki ✓. Maketteki tek koyu değer
///   (`#03140D`) gündüzde koyu zümrüt dolgunun (`okTx #08784F`) üstünde
///   ~3:1'in altına düşüyordu; gündüzde beyaza döner. İkisi de grafik
///   öğe eşiğini (3:1) geçmeli.
/// * `onGold`: Zêr üstündeki yıldız ve Sen avatarı, metin eşiği (4.5:1).
/// * `actShadow`: gece ve gündüzde ayrı ton; eylem gölgesi Agir ailesinde.
/// * `captionStrong`: Açıklama boyutunun 700 çeşidi; yeni bir boyut değil.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('✓ Rast dolgusunun üstünde iki temada da seçilir', () {
    for (final t in [SahneTokens.night, SahneTokens.day]) {
      expect(_contrast(t.onOk, t.okTx), greaterThanOrEqualTo(3));
    }
  });

  test('Zêr üstündeki glif metin eşiğini geçer', () {
    for (final t in [SahneTokens.night, SahneTokens.day]) {
      expect(_contrast(t.onGold, t.gold), greaterThanOrEqualTo(4.5));
    }
  });

  test('eylem gölgesi iki temada ayrı, Agir ailesinde', () {
    const night = SahneTokens.night;
    const day = SahneTokens.day;
    expect(night.actShadow, isNot(day.actShadow));
    expect(night.actShadowBlur, 24);
    expect(day.actShadowBlur, 20);
    for (final t in [night, day]) {
      final hue = HSLColor.fromColor(t.actShadow).hue;
      final act = HSLColor.fromColor(t.act).hue;
      expect((hue - act).abs(), lessThan(8));
    }
  });

  test('captionStrong Açıklama ölçüsündedir, yalnız kalınlığı farklı', () {
    expect(SahneType.captionStrong.fontSize, SahneType.caption.fontSize);
    expect(SahneType.captionStrong.height, SahneType.caption.height);
    expect(SahneType.captionStrong.fontWeight, FontWeight.w700);
  });

  test('lerp yeni alanları da taşır', () {
    final mid = SahneTokens.night.lerp(SahneTokens.day, 1);
    expect(mid.onOk, SahneTokens.day.onOk);
    expect(mid.actShadowBlur, SahneTokens.day.actShadowBlur);
    expect(mid.goldDeep, SahneTokens.day.goldDeep);
  });
}
