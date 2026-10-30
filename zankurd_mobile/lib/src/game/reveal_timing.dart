/// Cevap açıldıktan sonraki okuma arası; soru cevaplama süresinden ayrıdır.
abstract final class RevealTiming {
  static const live = Duration(seconds: 3);
  static const crowd = Duration(seconds: 4);

  /// Yeni zaman alanı olmayan sunucu hâlâ beş saniyeyi zorunlu tutar.
  static const legacy = Duration(seconds: 5);

  static Duration individual({required bool correct}) =>
      correct ? const Duration(milliseconds: 1200) : live;
}

/// Sunucu saat örneğini monoton yerel süreye bağlar. Cihazın duvar saati,
/// saat dilimi veya sonradan yapılan saat düzeltmesi geri sayımı değiştirmez.
class ServerRevealClock {
  ServerRevealClock({
    required DateTime serverNow,
    required this.endsAt,
    Duration Function()? elapsed,
  }) : _initialRemaining = endsAt.difference(serverNow),
       _elapsed = elapsed ?? _monotonicElapsed();

  final DateTime endsAt;
  final Duration _initialRemaining;
  final Duration Function() _elapsed;

  static Duration Function() _monotonicElapsed() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  Duration get remaining {
    final value = _initialRemaining - _elapsed();
    return value.isNegative ? Duration.zero : value;
  }

  int get secondsLeft => (remaining.inMicroseconds / 1000000).ceil();
}
