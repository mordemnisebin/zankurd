import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Onaylı mockup sistemi (2026-07-17): Kürdistan yeşili ana aksan, kâğıt-altın
// ikincil, koyu-sıcak yeşilimsi zemin. Bu test spec'teki hex değerlerinin
// token'lara yansıdığını doğrular — regresyonu (eski indigo/pembe palete
// dönüş) yakalar.
void main() {
  test('marka rengi Kürdistan yeşili', () {
    expect(AppTheme.brandOrange, const Color(0xFF3DA968));
    expect(AppTheme.brandOrangeWarm, const Color(0xFF2F7D4F));
  });

  test('öğrenme rengi yeşil', () {
    expect(AppTheme.playGreen, const Color(0xFF3DA968));
  });

  test('ödül/ikincil altını pirinç tonu', () {
    expect(AppTheme.gold, const Color(0xFFE7B53C));
    expect(AppTheme.secondaryAccent, const Color(0xFFE7B53C));
  });

  test('doğru/yanlış cevap renkleri mockup', () {
    expect(AppTheme.correct, const Color(0xFF3DA968));
    expect(AppTheme.wrong, const Color(0xFFE5533D));
  });

  test('açık mod zemin sıcak beyaz', () {
    expect(AppTheme.lightBg, const Color(0xFFFBF9F6));
  });

  test('koyu mod zemin koyu-sıcak yeşilimsi', () {
    expect(AppTheme.bg, const Color(0xFF0B0F0D));
    expect(AppTheme.surface, const Color(0xFF16211B));
    expect(AppTheme.border, const Color(0xFF26332B));
  });

  test('koyu mod metin kâğıt tonu', () {
    expect(AppTheme.textPrimary, const Color(0xFFF4F1E9));
  });
}
