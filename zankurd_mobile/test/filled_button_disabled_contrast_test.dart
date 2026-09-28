import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-09-03 simülatör: Ayarlar'daki pasif Kaydet turuncu-on-kahve
/// neredeyse okunmuyordu. Pasif FilledButton metni zemininden ayrılmalı.
void main() {
  testWidgets('koyu temada pasif zemin gece (çivit) ailesinde kalır', (
    tester,
  ) async {
    // Pasif zemin paletin kendi ailesinden olmalı: `#282A36` orman yeşili
    // paletinde mora kaçan bir leke gibi duruyordu (2026-09-27). Şahnê'de
    // (2026-09-29) palet çivit gecedir; pasif öğe Perde (s1) tonudur.
    late Color surface;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            surface = AppColors.disabledSurface(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final hue = HSVColor.fromColor(surface).hue;
    expect(hue, inInclusiveRange(220, 245), reason: 'ton: $hue ($surface)');
    expect(
      _contrastRatio(AppTheme.textMuted, surface),
      greaterThanOrEqualTo(4.5),
      reason: 'pasif düğmedeki soluk metin okunmalı',
    );
  });

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
