import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Zanîn paleti (2026-07-24 tasarım yenilemesi): kimlik Kesk (derin yeşil),
// eylem Tîrêj (koyu turuncu), ödül Zêr (altın). Aksan rolü 14 renkten 3'e
// indirildi. Bu test palet değerlerinin token'lara yansıdığını sabitler —
// regresyonu (eski neon/gradyan enflasyonlu palete dönüş) yakalar.
void main() {
  test('eylem rengi Tîrêj — beyaz metinle AA geçen koyu turuncu', () {
    expect(AppTheme.brand, const Color(0xFFC2560E));
    expect(AppTheme.brandDeep, const Color(0xFFA0450A));
    expect(AppTheme.brandLite, const Color(0xFFE2711D));
  });

  test('kimlik rengi Kesk — derin yeşil', () {
    expect(AppTheme.culturalBrandBg, const Color(0xFF14513A));
  });

  test('yardımcı aksanlar nötr bantta', () {
    expect(AppTheme.playGreen, const Color(0xFF3F8F5F));
    expect(AppTheme.playCyan, const Color(0xFF2F6F62));
    expect(AppTheme.playPurple, const Color(0xFF6B5AA6));
    expect(AppTheme.playPink, const Color(0xFFA85A7A));
  });

  test('ödül/ikincil altını Zêr tonu', () {
    expect(AppTheme.gold, const Color(0xFFD9A227));
    expect(AppTheme.secondaryAccent, const Color(0xFFD9A227));
  });

  test('doğru/yanlış cevap renkleri mockup', () {
    expect(AppTheme.correct, const Color(0xFF3DA968));
    expect(AppTheme.wrong, const Color(0xFFE5533D));
  });

  test('açık mod zemin sıcak kâğıt tonu', () {
    expect(AppTheme.lightBg, const Color(0xFFF7F4EE));
    expect(AppTheme.lightBorder, const Color(0xFFE7E0D4));
    expect(AppTheme.lightTextPrimary, const Color(0xFF1B201D));
  });

  test('koyu mod zemin gece yeşili — yüzey zeminden bir tık açık', () {
    expect(AppTheme.bg, const Color(0xFF0E1512));
    expect(AppTheme.surface, const Color(0xFF18211B));
    expect(AppTheme.border, const Color(0xFF2A362E));
  });

  test('koyu mod metin kâğıt tonu', () {
    expect(AppTheme.textPrimary, const Color(0xFFF6F3EC));
  });
}
