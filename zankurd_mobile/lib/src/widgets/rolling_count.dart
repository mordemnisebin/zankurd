import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reduced_motion_provider.dart';

/// Sayıyı hedefe DOĞRU sayarak çıkar.
///
/// ## Niçin
///
/// Ödül anları uygulamada yazıyla anlatılıyordu: skor birden beliriyor,
/// jeton "+50c" olarak yazılıyordu. Yazı okunur, hissedilmez. Bir sayının
/// tırmanışını izlemek kazanmanın kendisidir — yarışma programlarının,
/// slot makinelerinin ve her oyun ekonomisinin aynı şeyi yapmasının
/// sebebi bu. Değişiklik tek bir bileşende toplanır ki ödül gösteren her
/// yer aynı ritmi kullansın.
///
/// ## Süre niçin farka bağlı
///
/// Sabit süre iki uçta da yanlış: 3 puanlık artış uzun uzun sayılırsa
/// komik, 4200 puanlık artış aynı sürede sayılırsa okunamayan bir
/// bulanıklık olur. Süre farkla birlikte büyür ama tavanı vardır;
/// kullanıcı sonuç ekranında sayının bitmesini bekleyemez.
class RollingCount extends StatelessWidget {
  const RollingCount({
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.maxLines = 1,
    super.key,
  });

  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final int maxLines;

  static const Duration _minDuration = Duration(milliseconds: 380);
  static const Duration _maxDuration = Duration(milliseconds: 1100);

  static Duration durationFor(int delta) {
    final magnitude = delta.abs();
    // Her 100 birim için ~90 ms; tavan aşılmaz.
    final ms = _minDuration.inMilliseconds + (magnitude * 0.9).round();
    return Duration(
      milliseconds: ms.clamp(
        _minDuration.inMilliseconds,
        _maxDuration.inMilliseconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hareket azaltma açıkken sayım YAPILMAZ.
    //
    // Sağlayıcı yoksa (bileşeni izole eden testler) sessizce sayar;
    // dekoratif bir davranış, ağacı eksik diye ekranı çökertmemeli —
    // `KilimReveal` ile aynı ilke.
    final reduced =
        context.watch<ReducedMotionProvider?>()?.reduceMotion ?? false;
    if (reduced) {
      return Text(
        '$prefix$value$suffix',
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return TweenAnimationBuilder<double>(
      // Her zaman SIFIRDAN sayılır, önceki değerden değil. Sonuç ekranı
      // her turda yeniden kurulur; "önceki değer" diye bir şey yok ve
      // olduğunu varsaymak ilk karede hedefe atlamaya yol açıyordu.
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: durationFor(value),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text(
        '$prefix${current.round()}$suffix',
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
