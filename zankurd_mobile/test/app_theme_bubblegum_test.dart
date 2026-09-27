import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// ZanKurd Design 2.0: Forest kimlik, Ember eylem, Sun ödül ve Cream/Ink
// okuma yüzeyi. CTA'daki Ember 600 tonu, beyaz metinle AA için spec'e en
// yakın erişilebilir koyu varyanta çekilir; diğer ana tokenlar Design 2
// belgesindeki değerleri doğrudan taşır.
void main() {
  test('eylem rengi Tîrêj — beyaz metinle AA geçen koyu turuncu', () {
    expect(AppTheme.brand, const Color(0xFFC75209));
    expect(AppTheme.brandDeep, const Color(0xFFA03B0A));
    expect(AppTheme.brandLite, const Color(0xFFE06A16));
  });

  test('kimlik rengi Kesk — Design 2 Forest', () {
    expect(AppTheme.culturalBrandBg, const Color(0xFF20533A));
  });

  test('yardımcı aksanlar kontrollü kategori bandında', () {
    expect(AppTheme.playGreen, const Color(0xFF2F7450));
    expect(AppTheme.playCyan, const Color(0xFF2F6F62));
    expect(AppTheme.playPurple, const Color(0xFF6B5AA6));
    expect(AppTheme.playPink, const Color(0xFFA85A7A));
  });

  test('ödül altını Design 2 Sun tonu', () {
    expect(AppTheme.gold, const Color(0xFFE9A91B));
    expect(AppTheme.secondaryAccent, const Color(0xFFE9A91B));
  });

  test('doğru/yanlış cevap renkleri mockup', () {
    expect(AppTheme.correct, const Color(0xFF3DA968));
    expect(AppTheme.wrong, const Color(0xFFE5533D));
  });

  test('açık mod zemin sıcak kâğıt tonu', () {
    expect(AppTheme.lightBg, const Color(0xFFFBF7EE));
    expect(AppTheme.lightBgDeep, const Color(0xFFF4EBDD));
    expect(AppTheme.lightBorder, const Color(0xFFE7ECE6));
    expect(AppTheme.lightTextPrimary, const Color(0xFF171812));
  });

  test('koyu mod Design 2 Forest katmanlarını kullanır', () {
    expect(AppTheme.bg, const Color(0xFF0A1712));
    expect(AppTheme.surface, const Color(0xFF10251C));
    expect(AppTheme.surfaceHi, const Color(0xFF17382A));
    expect(AppTheme.border, const Color(0xFF20533A));
  });

  test('koyu mod metin kâğıt tonu', () {
    expect(AppTheme.textPrimary, const Color(0xFFFBF7EE));
  });

  test('sayfa ve AppBar başlıkları rafine w700 hiyerarşisini paylaşır', () {
    expect(AppTypography.heading1.fontWeight, FontWeight.w700);
    expect(
      AppTheme.dark().appBarTheme.titleTextStyle?.fontWeight,
      FontWeight.w700,
    );
    expect(
      AppTheme.light().appBarTheme.titleTextStyle?.fontWeight,
      FontWeight.w700,
    );
  });
}
