import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

/// 2026-09-03 simülatör: Ayarlar'daki pasif Kaydet turuncu-on-kahve
/// neredeyse okunmuyordu. Pasif FilledButton metni zemininden ayrılmalı.
void main() {
  panelCilasiPasifDugme();
  // Tasarım kurulu tüm ekranlar 2026-10-20: pasif düğme zemini her yerde
  // ortak jetondur; el yazması `s1`/`s2` pasif dolgu (Ayarlar Kaydet,
  // alanla aynı gri-gri) geri gelmesin.
  test('pasif düğme dolgusu yalnız ortak jetondan gelir', () {
    final offenders = <String>[];
    for (final f in Directory('lib/src').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(
          r'disabledBackgroundColor:\s*[\w.()]*\.(s1|s2|s3)\b',
        ).hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'disabledFill kullanılmalı');
  });

  testWidgets('koyu temada pasif zemin gece (grafit) ailesinde kalır', (
    tester,
  ) async {
    // Pasif zemin paletin kendi ailesinden olmalı: `#282A36` orman yeşili
    // paletinde mora kaçan bir leke gibi duruyordu (2026-09-27). Gece paleti
    // kuruldu 2026-10-20 (oy birliğiyle B): nötr grafit, mavi ton yok; pasif
    // zemin `#282A2F` (tx3 etiketle ≥ 4.5).
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
    final sat = HSVColor.fromColor(surface).saturation;
    expect(sat, lessThan(0.15), reason: 'nötr grafit olmalı: $surface');
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
        greaterThanOrEqualTo(3.0),
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

/// Son panel cilası 2026-10-19: pasif dolu düğme sayfa zeminine karışıyordu
/// (oda lobisi, tek oyuncu "Yarışı başlat"). Her iki temada pasif dolgu
/// zeminden gözle ayrılır, etiket dolguya karşı >= 4.5.
void panelCilasiPasifDugme() {
  test('pasif dolgu zeminden ayrılır, etiket okunur (gündüz ve gece)', () {
    for (final t in [SahneTokens.day, SahneTokens.night]) {
      expect(
        _contrastRatio(t.disabledFill, t.bg),
        greaterThanOrEqualTo(1.08),
        reason: 'pasif dolgu zeminden ayrılmalı',
      );
      // Kurul 3. tur 2026-10-20: pasif etiket etkin etiketten soluk ama ≥ 3.
      expect(
        _contrastRatio(t.disabledFg, t.disabledFill),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(t.tx, t.disabledFill),
        greaterThan(_contrastRatio(t.disabledFg, t.disabledFill)),
        reason: 'pasif etiket etkin etiketten soluk olmalı',
      );
      // İkincil kenar zeminde görünür (≥ 1,8); pasif kenarsız.
      expect(
        _contrastRatio(t.secondaryEdge, t.bg),
        greaterThanOrEqualTo(1.8),
        reason: 'ikincil düğme kenarı görünür olmalı',
      );
    }
    expect(SahneTokens.day.disabledFill, const Color(0xFFE3E7F0));
  });
}
