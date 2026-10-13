import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

/// Şahnê paletinin bekçisi.
///
/// ## Karar
///
/// 2026-09-29'da üç tasarım yönü maketlenip karşılaştırıldı ve "Şahnê —
/// Gece sahnesi" seçildi. Bu dosya eski "Design 2.0 Forest/Ember/Cream"
/// bekçisinin (`app_theme_bubblegum_test`) yerini alır: o test yeşil kimlik
/// ve krem zemin kararını sabitliyordu; ölçülen sorun (ortak kuralın
/// olmaması, kategori çizimleriyle kavga eden yeşil) o kararın kendisiydi.
///
/// ## Neyi korur
///
/// 1. Rol renkleri tek kaynaktan gelir: eski `AppTheme` adları (`brand`,
///    `playRed`, `gold`, `bg` …) taşınmamış ekranlar için hâlâ duruyor ve
///    Şahnê belirteçlerine eşit olmalı — ikisi ayrışırsa aynı ekranda iki
///    palet görünür.
/// 2. Birincil eylem metni Agir üstünde AA geçer (koyu metin, 8:1 üstü).
/// 3. Rol ve durum ayrıdır: yarış (Boyax) ile yanlış (Şaş) aynı renk değil.
/// 4. Metnin üç basamağı her iki temada da zeminde AA geçer; silik gri yok.
void main() {
  const night = SahneTokens.night;
  const day = SahneTokens.day;

  test('eski adlar Şahnê rollerine eşit (tek palet)', () {
    expect(AppTheme.brand, night.act);
    expect(AppTheme.playRed, night.race);
    expect(AppTheme.gold, night.gold);
    expect(AppTheme.secondaryAccent, night.gold);
    expect(AppTheme.bg, night.bg);
    expect(AppTheme.surface, night.s1);
    expect(AppTheme.surfaceHi, night.s2);
    expect(AppTheme.textPrimary, night.tx);
    expect(AppTheme.textSub, night.tx2);
    expect(AppTheme.textMuted, night.tx3);
    expect(AppTheme.lightBg, day.bg);
    expect(AppTheme.lightSurface, day.s1);
    expect(AppTheme.lightTextPrimary, day.tx);
    expect(AppTheme.lightTextSub, day.tx2);
    expect(AppTheme.lightTextMuted, day.tx3);
    expect(AppTheme.wrong, night.errTx);
  });

  test('temalar Şahnê belirteçlerini taşır', () {
    expect(AppTheme.dark().extension<SahneTokens>(), night);
    expect(AppTheme.light().extension<SahneTokens>(), day);
    expect(AppTheme.dark().scaffoldBackgroundColor, night.bg);
    expect(AppTheme.light().scaffoldBackgroundColor, day.bg);
  });

  test('birincil eylem: Agir üstünde koyu metin AA geçer', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final style = theme.filledButtonTheme.style!;
      final fg = style.foregroundColor!.resolve({})!;
      final bg = style.backgroundColor!.resolve({})!;
      expect(bg, night.act);
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    }
  });

  test('yarış rengi ile yanlış rengi ayrıdır', () {
    // Tur 2'de Boyax kırmızıdan lale (340°) çekildi ki "yanlış" (~5°) ile
    // karışmasın; durum her zaman şekille de verilir, ama renk de ayrılır.
    final race = HSLColor.fromColor(night.race).hue;
    final err = HSLColor.fromColor(night.errTx).hue;
    final distance = math.min((race - err).abs(), 360 - (race - err).abs());
    expect(distance, greaterThan(20), reason: 'race=$race err=$err');
  });

  test('üç metin basamağı iki temada da zeminde AA geçer', () {
    for (final t in [night, day]) {
      for (final text in [t.tx, t.tx2, t.tx3]) {
        expect(_contrast(text, t.bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(text, t.s1), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('başlıklar Bricolage Grotesque 800, metin Onest', () {
    expect(SahneType.title.fontFamily, SahneType.display);
    expect(SahneType.title.fontWeight, FontWeight.w800);
    expect(SahneType.body.fontFamily, SahneType.text);
    expect(
      AppTheme.dark().appBarTheme.titleTextStyle?.fontFamily,
      SahneType.display,
    );
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
