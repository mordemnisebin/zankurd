import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Ronahî Arcade (2026-07-15): Google AI Studio referansındaki kompakt oyun
// hiyerarşisini açık-varsayılan, turuncu/indigo ZanKurd paletiyle birleştirir.
void main() {
  test('marka rengi Ronahî turuncusu', () {
    expect(AppTheme.brandOrange, const Color(0xFFE57832));
    expect(AppTheme.brandOrangeWarm, const Color(0xFFF09A52));
  });

  test('öğrenme rengi dengeli yeşil', () {
    expect(AppTheme.playGreen, const Color(0xFF4EA66A));
  });

  test('1v1/rekabet rengi kontrollü mercan', () {
    expect(AppTheme.playPink, const Color(0xFFD94D72));
  });

  test('oda/mod rengi bilgi mavisi', () {
    expect(AppTheme.playCyan, const Color(0xFF2D8BD8));
  });

  test('profil ve şans vurgusu indigo', () {
    expect(AppTheme.playPurple, const Color(0xFF5147C7));
  });

  test('ödül altını daha okunaklıdır', () {
    expect(AppTheme.gold, const Color(0xFFE9B949));
  });

  test('açık mod yüzeyleri soğuk ve ferahtır', () {
    expect(AppTheme.lightBg, const Color(0xFFF5F7FC));
    expect(AppTheme.lightSurface, const Color(0xFFFFFFFF));
    expect(AppTheme.lightSurfaceHi, const Color(0xFFEEF2FA));
    expect(AppTheme.lightTextPrimary, const Color(0xFF171B2E));
  });

  test('koyu mod yüzeyleri nötr ve eksiksizdir', () {
    expect(AppTheme.bg, const Color(0xFF101217));
    expect(AppTheme.surface, const Color(0xFF171C29));
    expect(AppTheme.surfaceHi, const Color(0xFF202739));
  });
}
