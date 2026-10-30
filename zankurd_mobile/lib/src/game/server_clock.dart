/// RPC saat örneğini cihaz saatinden bağımsız, monoton bir saate bağlar.
/// RTT/2 ağ aktarımı tahminidir; asimetrik ağda kesin eşitlik garantisi yoktur.
class ServerClock {
  factory ServerClock({
    required DateTime serverNow,
    Duration roundTrip = Duration.zero,
    DateTime? localReceivedAt,
    Duration Function()? elapsed,
  }) {
    final receivedAt = localReceivedAt ?? DateTime.now();
    final estimatedNow = serverNow.add(roundTrip ~/ 2);
    final watch = elapsed == null ? (Stopwatch()..start()) : null;
    return ServerClock._(
      receivedAt,
      estimatedNow.difference(receivedAt),
      elapsed ?? () => watch!.elapsed,
    );
  }

  ServerClock._(this._receivedAt, this.offset, this._elapsed);

  final DateTime _receivedAt;
  final Duration Function() _elapsed;

  /// Örnek alındığı anda sunucu - cihaz duvar saati farkı.
  final Duration offset;

  DateTime get now => _receivedAt.add(offset).add(_elapsed());

  Duration remainingUntil(DateTime deadline) {
    final remaining = deadline.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
