import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-07-22 canlı UX denetimi (P1-A): renkli zeminlerin üzerine aynı renk
/// ailesinden metin konması beş ayrı ekranda tekrar ediyordu — profil
/// "Bronz Lig" rozeti, sonuç ekranı yıldız + istatistik etiketleri, çark
/// kutlama bandı, turnuva çipi, kategori kartı alt metni.
///
/// Bu testler düzeltmelerin ardındaki renk kararlarını sabitler.
double _luminance(Color c) => c.computeLuminance();

double contrastRatio(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// [foreground]'ı [background] üzerine alfa harmanlayarak gerçek rengi bulur.
Color _flatten(Color foreground, Color background) {
  final a = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}

void main() {
  group('renkli zemin üzerinde okunabilirlik', () {
    test('turuncu hero üzerinde beyaz metin tek başına yetmez', () {
      // Düzeltmenin gerekçesi: hero gradyanında beyaz metin AA'yı geçmiyor,
      // bu yüzden rozet/pill'lere koyu yarı saydam zemin eklendi.
      expect(
        contrastRatio(Colors.white, AppTheme.primaryGradientStart),
        lessThan(4.5),
      );
    });

    test('heroScrim eklenince beyaz metin AA eşiğini geçer', () {
      // Hem açık turuncu (gradyan başı) hem koyu turuncu (profil hero'su)
      // üzerinde eşiğin üstünde kalmalı.
      for (final background in [
        AppTheme.primaryGradientStart,
        AppTheme.brandDeep,
      ]) {
        final scrim = _flatten(AppColors.heroScrim(), background);
        expect(
          contrastRatio(Colors.white, scrim),
          greaterThanOrEqualTo(4.5),
          reason: 'zemin $background',
        );
      }
    });

    test('altın bant üzerinde koyu mürekkep AA eşiğini geçer', () {
      expect(contrastRatio(AppTheme.bg, AppTheme.gold), greaterThanOrEqualTo(4.5));
      // Eski hâli (beyaz) geçmiyordu.
      expect(contrastRatio(Colors.white, AppTheme.gold), lessThan(3));
    });
  });

  group('AppColors.readableAccent', () {
    testWidgets('açık temada açık aksanı okunabilir açıklığa çeker', (
      tester,
    ) async {
      late Color adapted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              adapted = AppColors.readableAccent(context, AppTheme.gold);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        contrastRatio(adapted, AppTheme.lightSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'altın aksan açık yüzeyde okunabilir olmalı',
      );
      // Aksan kimliği korunmalı: ton kayması olmamalı.
      expect(
        HSLColor.fromColor(adapted).hue,
        closeTo(HSLColor.fromColor(AppTheme.gold).hue, 1),
      );
    });

    testWidgets('koyu temada aksan olduğu gibi kalır veya aydınlatılır', (
      tester,
    ) async {
      late Color adapted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              adapted = AppColors.readableAccent(context, AppTheme.gold);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        contrastRatio(adapted, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
