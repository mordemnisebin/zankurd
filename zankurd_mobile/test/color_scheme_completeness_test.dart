import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Tema, Material'ın rol sözlüğünü eksiksiz doldurur.
///
/// ## Kusur
///
/// `AppTheme.dark()` ve `light()` şemayı `ColorScheme.fromSeed` yerine ham
/// `const ColorScheme(...)` ile kuruyor ve yalnız 10 rol veriyordu:
/// primary/onPrimary/secondary/onSecondary/tertiary/error/onError/
/// surface/onSurface. Geri kalan roller Flutter'ın getter fallback'lerine
/// düşer (`color_scheme.dart`): `surfaceContainer*` → `surface`,
/// `primaryContainer` → `primary`, `outline` → `onBackground` → `onSurface`.
///
/// Yani "container" tonları üstünde durdukları yüzeyle BİREBİR aynı renk,
/// "outline" ise metin rengi kadar sert oluyordu. Kusur sessizdi çünkü
/// uygulama kendi kart ve çip widget'larını kullanıyor; yalnız Material'ın
/// hazır bileşenlerine dokunduğu üç yerde görünüyordu:
///
/// * Ayarlar → seslendirme kaydırıcısının pasif rayı kartla aynı renkti,
///   kullanıcı sesin nereye kadar gidebileceğini göremiyordu.
/// * Bildirim saati seçicisinin kadran diski zeminde kayboluyordu.
/// * Gözden Geçir → Liste/Flaşkart bölünmüş düğmesinde seçili sekmenin
///   beyaz metni altın zeminde 2,30:1 kalıyordu (AA eşiği 4,5:1).
///
/// Kök nedeni tek noktadan kapatmak, üç kusuru birden kapatır — ve
/// ileride eklenecek her M3 bileşenini de doğru doğurtur.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = <String, ThemeData>{
    'dark': AppTheme.dark(),
    'light': AppTheme.light(),
  };

  themes.forEach((name, theme) {
    final scheme = theme.colorScheme;

    group('$name teması', () {
      test('container tonları yüzeyden ayrışır', () {
        // Fallback'e düşen her rol `surface`e eşit olurdu.
        final containers = <String, Color>{
          'surfaceContainerLow': scheme.surfaceContainerLow,
          'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
        };
        containers.forEach((role, color) {
          if (role == 'surfaceContainer') return; // yüzeyin kendisi olabilir
          expect(
            color,
            isNot(scheme.surface),
            reason: '$role yüzeyle aynı renk — fallback e düşmüş.',
          );
        });
      });

      test('outline metin rengine düşmez', () {
        expect(
          scheme.outline,
          isNot(scheme.onSurface),
          reason: 'outline → onSurface fallback i aşırı sert kenarlık verir.',
        );
        expect(scheme.outlineVariant, isNot(scheme.onSurface));
      });

      test('aksan container ları aksanın kendisi değildir', () {
        expect(scheme.primaryContainer, isNot(scheme.primary));
        expect(scheme.secondaryContainer, isNot(scheme.secondary));
        expect(scheme.tertiaryContainer, isNot(scheme.tertiary));
        expect(scheme.errorContainer, isNot(scheme.error));
      });

      test('container üzerindeki metinler AA eşiğini geçer', () {
        final pairs = <String, (Color, Color)>{
          'primary': (scheme.onPrimaryContainer, scheme.primaryContainer),
          'secondary': (scheme.onSecondaryContainer, scheme.secondaryContainer),
          'tertiary': (scheme.onTertiaryContainer, scheme.tertiaryContainer),
          'error': (scheme.onErrorContainer, scheme.errorContainer),
          'surfaceVariant': (scheme.onSurfaceVariant, scheme.surface),
        };
        pairs.forEach((label, pair) {
          final ratio = _contrast(pair.$1, pair.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$label container kontrastı ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });

      test('yükseklik tonlaması yüzeyi renklendirmez', () {
        // Varsayılan `surfaceTint` primary dir: yükselen her Material
        // yüzeyi marka turuncusuna çalardı. Uygulama düz yüzey kullanıyor.
        expect(scheme.surfaceTint, scheme.surface);
      });

      test('kaydırıcının pasif rayı zeminden ayrışır', () {
        final slider = theme.sliderTheme;
        expect(slider.inactiveTrackColor, isNotNull);
        expect(
          slider.inactiveTrackColor,
          isNot(scheme.surface),
          reason: 'Pasif ray, üstünde durduğu kartla aynı renk olamaz.',
        );
        expect(slider.activeTrackColor, isNotNull);
        expect(slider.activeTrackColor, isNot(slider.inactiveTrackColor));
      });

      test('saat seçici ve bölünmüş düğme temasız kalmaz', () {
        expect(theme.timePickerTheme.dialBackgroundColor, isNotNull);
        expect(
          theme.timePickerTheme.dialBackgroundColor,
          isNot(theme.timePickerTheme.backgroundColor),
          reason: 'Kadran diski diyalog zeminiyle aynıysa görünmez.',
        );
        expect(theme.segmentedButtonTheme.style, isNotNull);
      });
    });
  });

  test('bölünmüş düğmenin seçili metni zeminiyle AA eşiğini geçer', () {
    for (final theme in themes.values) {
      final style = theme.segmentedButtonTheme.style!;
      const selected = <WidgetState>{WidgetState.selected};
      final bg = style.backgroundColor!.resolve(selected)!;
      final fg = style.foregroundColor!.resolve(selected)!;
      final ratio = _contrast(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'Seçili segment kontrastı ${ratio.toStringAsFixed(2)}:1 — '
            'stilsiz hâlinde beyaz metin altın zeminde 2,30:1 kalıyordu.',
      );
    }
  });
}
