import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/weekly_cup_schedule.dart';

/// 2026-07-26 denetimi: turnuva geri sayımı Cumartesi 20:00'dan sonra
/// negatife düşüyordu. Sebep sessizdi — `nextSaturday.add(...)` çağrılıp
/// dönüş değeri atılıyordu; `DateTime.add` var olan nesneyi değiştirmez.
/// Analiz aracı bunu bildirmez, çünkü sözdizimi geçerlidir.
///
/// Mantık saf bir işleve çıkarıldı; bu testler hatanın geri dönmesini
/// engeller.
void main() {
  test('hafta içi bir günde, gelen Cumartesi 20:00 döner', () {
    // 2026-07-22 Çarşamba, 09:00
    final now = DateTime(2026, 7, 22, 9);
    final next = nextWeeklyCupAfter(now);

    expect(next.weekday, DateTime.saturday);
    expect(next, DateTime(2026, 7, 25, 20));
    expect(next.isAfter(now), isTrue);
  });

  test('Cumartesi saat 20:00’dan önce, aynı günü döner', () {
    final now = DateTime(2026, 7, 25, 19, 59);
    expect(nextWeeklyCupAfter(now), DateTime(2026, 7, 25, 20));
  });

  test('tam kupa saatinde bir sonraki haftaya geçer', () {
    // Asıl hata buradaydı: geri sayım sıfırda kalıyordu.
    final now = DateTime(2026, 7, 25, 20);
    final next = nextWeeklyCupAfter(now);

    expect(next, DateTime(2026, 8, 1, 20));
    expect(next.difference(now), const Duration(days: 7));
  });

  test('Cumartesi 20:00’dan sonra geri sayım negatif olmaz', () {
    final now = DateTime(2026, 7, 25, 23, 30);
    final next = nextWeeklyCupAfter(now);

    expect(next.isAfter(now), isTrue);
    expect(next.difference(now).isNegative, isFalse);
    expect(next, DateTime(2026, 8, 1, 20));
  });

  test('her gün ve saat için sonuç gelecekte ve Cumartesidir', () {
    // Kaba kuvvet: bir yıl boyunca saat başı. Kenar durumlar (ay/yıl
    // sınırı, yaz saati) elle örneklenerek değil, taranarak kapanır.
    var now = DateTime(2026, 1, 1);
    while (now.isBefore(DateTime(2027, 1, 1))) {
      final next = nextWeeklyCupAfter(now);
      expect(next.isAfter(now), isTrue, reason: 'geçmişe düştü: $now → $next');
      expect(next.weekday, DateTime.saturday, reason: 'Cumartesi değil: $next');
      expect(next.hour, 20, reason: 'saat 20 değil: $next');
      expect(
        next.difference(now).inDays,
        lessThan(8),
        reason: 'bir haftadan uzak: $now → $next',
      );
      now = now.add(const Duration(hours: 1));
    }
  });
}
