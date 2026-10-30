import 'server_clock.dart';

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
  }) : clock = ServerClock(serverNow: serverNow, elapsed: elapsed);

  ServerRevealClock.fromServerClock({
    required this.clock,
    required this.endsAt,
  });

  final DateTime endsAt;
  final ServerClock clock;

  Duration get remaining => clock.remainingUntil(endsAt);

  int get secondsLeft => (remaining.inMicroseconds / 1000000).ceil();
}
