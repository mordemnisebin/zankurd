/// Haftalık kupanın bir sonraki başlangıç anı.
///
/// Mantık ekranın `build` gövdesine gömülüydü ve orada sessiz bir hata
/// barındırıyordu: `nextSaturday.add(...)` çağrılıp dönüş değeri atılıyordu.
/// `DateTime.add` yeni bir nesne döndürür, var olanı değiştirmez — üstelik
/// değişken `final` olduğu için değiştirilemezdi de. Sonuç, Cumartesi
/// 20:00'dan sonra geri sayımın negatife düşmesiydi (2026-07-26 denetimi).
///
/// Saf bir işleve çıkarıldı ki hata bir daha girerse test yakalasın;
/// `build` içinde `DateTime.now()` ile çalışan mantık test edilemez.
library;

/// Kupanın haftalık günü ve saati.
const int weeklyCupWeekday = DateTime.saturday;
const int weeklyCupHour = 20;

/// [now] anından sonraki ilk kupa başlangıcı.
///
/// Tam kupa saatinde çağrılırsa **bir sonraki haftayı** döndürür: o an kupa
/// başlamıştır, geri sayım sıfırda takılı kalmamalıdır.
DateTime nextWeeklyCupAfter(DateTime now) {
  final daysUntil = (weeklyCupWeekday - now.weekday + 7) % 7;
  var next = DateTime(now.year, now.month, now.day + daysUntil, weeklyCupHour);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 7));
  }
  return next;
}
