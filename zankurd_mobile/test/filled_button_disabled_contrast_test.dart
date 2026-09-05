import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-09-03 simülatör: Ayarlar'daki pasif Kaydet turuncu-on-kahve
/// neredeyse okunmuyordu. Pasif FilledButton metni zemininden ayrılmalı.
void main() {
  test(
    'koyu temada pasif FilledButton kontrastı WCAG AA metin tabanını geçer',
    () {
      final style = AppTheme.dark().filledButtonTheme.style!;
      const disabled = {WidgetState.disabled};
      final fg = style.foregroundColor!.resolve(disabled)!;
      final bg = style.backgroundColor!.resolve(disabled)!;
      expect(
        _contrastRatio(fg, bg),
        greaterThanOrEqualTo(4.5),
        reason: 'pasif Kaydet okunaklı olmalı (fg=$fg bg=$bg)',
      );
    },
  );
}

double _contrastRatio(Color a, Color b) {
  final la = _relLuminance(a);
  final lb = _relLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relLuminance(Color color) {
  double lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(color.r) + 0.7152 * lin(color.g) + 0.0722 * lin(color.b);
}
