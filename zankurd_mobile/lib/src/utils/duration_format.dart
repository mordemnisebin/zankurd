/// Süreleri insan-okunur biçimde böler: "6 roj 10 saet" / "6 gün 10 saat".
///
/// "154 saet 51 deqîqe" gibi ham saat+dakika yığınları yerine en büyük iki
/// birimi (roj/saet/deqîqe) gösterir. Kurmancî/Türkçe iki dilli.
library;

/// [duration] için en büyük iki birimi döndürür.
///
/// Örnekler:
/// - 6 gün 10 saat  → "6 roj 10 saet" / "6 gün 10 saat"
/// - 3 saat 45 dk   → "3 saet 45 deqîqe" / "3 saat 45 dakika"
/// - 12 dk          → "12 deqîqe" / "12 dakika"
/// - 0              → "0 deqîqe" / "0 dakika"
String formatDurationHuman(Duration duration, {required bool ku}) {
  var remaining = duration.isNegative ? Duration.zero : duration;
  final days = remaining.inDays;
  remaining -= Duration(days: days);
  final hours = remaining.inHours;
  remaining -= Duration(hours: hours);
  final minutes = remaining.inMinutes;

  String unit(int value, String kuForm, String trForm) =>
      '$value ${ku ? kuForm : trForm}';

  final parts = <String>[
    if (days > 0) unit(days, 'roj', 'gün'),
    if (hours > 0) unit(hours, 'saet', 'saat'),
    if (days == 0 && minutes > 0) unit(minutes, 'deqîqe', 'dakika'),
  ];

  if (parts.isEmpty) return unit(0, 'deqîqe', 'dakika');
  return parts.take(2).join(' ');
}
