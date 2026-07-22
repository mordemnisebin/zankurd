import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-07-22 canlı UX denetimi (P1-C): A/B/C/D şık harfleri sırasıyla
/// kırmızı, mavi, yeşil, kehribar renkteydi. Quiz bağlamında kırmızı
/// "yanlış", yeşil "doğru" demektir; cevaplamadan önce bir şıkkı yeşil,
/// birini kırmızı göstermek sahte ipucu veriyordu.
double _hue(Color c) => HSLColor.fromColor(c).hue;

void main() {
  test('şık kimlik renkleri geri bildirim renkleriyle çakışmaz', () {
    final correctHue = _hue(AppTheme.correct);
    final wrongHue = _hue(AppTheme.wrong);

    for (final color in AppTheme.answerOptionColors) {
      final hue = _hue(color);
      expect(
        (hue - correctHue).abs(),
        greaterThan(30),
        reason: 'şık rengi "doğru" yeşiline çok yakın: $color',
      );
      expect(
        (hue - wrongHue).abs(),
        greaterThan(30),
        reason: 'şık rengi "yanlış" kırmızısına çok yakın: $color',
      );
    }
  });

  test('dört şık rengi birbirinden ayırt edilebilir', () {
    final hues = AppTheme.answerOptionColors.map(_hue).toList();
    for (var i = 0; i < hues.length; i++) {
      for (var j = i + 1; j < hues.length; j++) {
        expect(
          (hues[i] - hues[j]).abs(),
          greaterThan(20),
          reason: '${i + 1}. ve ${j + 1}. şık renkleri birbirine çok yakın',
        );
      }
    }
  });

  test('dört şık için renk tanımlı', () {
    expect(AppTheme.answerOptionColors.length, 4);
  });
}
