import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-07-22 canlı UX denetimi (P1-C): A/B/C/D şık harfleri sırasıyla
/// kırmızı, mavi, yeşil, kehribar renkteydi. Quiz bağlamında kırmızı
/// "yanlış", yeşil "doğru" demektir; cevaplamadan önce bir şıkkı yeşil,
/// birini kırmızı göstermek sahte ipucu veriyordu.
///
/// 2026-07-24 canlı denetim (devam): renkler ayrıştırıldı ama sorun
/// sürüyordu — dört doygun ton (mavi/mor/camgöbeği/kehribar) oyuncuya
/// şıklar arasında bir *fark* olduğunu ima ediyordu. Oysa şık harfi yalnız
/// bir etikettir. Artık dördü de tek nötr tondur; renk yalnız cevaptan
/// sonra, doğru/yanlış anında konuşur.
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

  test('şık harfleri renkle ayrışmaz — hepsi tek nötr ton', () {
    final unique = AppTheme.answerOptionColors.toSet();
    expect(
      unique,
      hasLength(1),
      reason:
          'Şık harflerine farklı renkler verildi; renk burada anlam '
          'taşımıyor ve sahte hiyerarşi yaratıyor.',
    );
  });

  test('nötr ton düşük doygunluktadır (aksanlarla yarışmaz)', () {
    for (final color in AppTheme.answerOptionColors) {
      final saturation = HSLColor.fromColor(color).saturation;
      expect(saturation, lessThan(0.35), reason: '$color çok doygun');
    }
  });

  test('dört şık için renk tanımlı', () {
    expect(AppTheme.answerOptionColors.length, 4);
  });
}
