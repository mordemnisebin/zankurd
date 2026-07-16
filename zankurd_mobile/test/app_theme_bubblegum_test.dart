import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Bubblegum Arcade (2026-07-12): turuncu/mor bırakıldı, yeni bağımsız
// palet. Bu test spec'teki hex değerlerinin token'lara yansıdığını
// doğrular — regresyonu (eski turuncuya dönüş) yakalar.
void main() {
  test('marka rengi indigo Bubblegum Arcade paleti', () {
    expect(AppTheme.brandOrange, const Color(0xFF2D3561));
    expect(AppTheme.brandOrangeWarm, const Color(0xFF4B5AA8));
  });

  test('öğrenme rengi lime', () {
    expect(AppTheme.playGreen, const Color(0xFF8BC53F));
  });

  test('1v1/rekabet rengi sıcak pembe', () {
    expect(AppTheme.playPink, const Color(0xFFFF3B81));
  });

  test('oda/mod rengi gökmavi', () {
    expect(AppTheme.playCyan, const Color(0xFF38BDF8));
  });

  test('özel mod moru indigo ile birleşir', () {
    expect(AppTheme.playPurple, const Color(0xFF6C5CE7));
  });

  test('ödül altını değişmez kalır', () {
    expect(AppTheme.gold, const Color(0xFFE9C46A));
  });

  test('açık mod zemin sıcak beyaz', () {
    expect(AppTheme.lightBg, const Color(0xFFFBF9F6));
  });

  test('koyu mod zemin yeni indigo-koyu tonu', () {
    expect(AppTheme.bg, const Color(0xFF12141C));
  });
}
