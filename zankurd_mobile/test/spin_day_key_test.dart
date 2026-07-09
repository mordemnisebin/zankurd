import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

// Regression: günlük çark guard'ı sunucudaki CURRENT_DATE (UTC) ile aynı gün
// sınırını kullanmalı. Yerel tarih kullanılınca yerel gece yarısı ile UTC gece
// yarısı arasında buton aktif görünüp sunucunun reddettiği "çark dönmüyor /
// bugün zaten çevirdin" tutarsızlığı yaşanıyordu.
void main() {
  group('SupabaseZanKurdRepository.spinDayKey', () {
    test('UTC gününü kullanır, yerel saat diliminden etkilenmez', () {
      // UTC+3'te 11 Temmuz 01:30; UTC'de hâlâ 10 Temmuz 22:30.
      final localAfterMidnight = DateTime.utc(2026, 7, 10, 22, 30);
      expect(
        SupabaseZanKurdRepository.spinDayKey(localAfterMidnight),
        '2026-7-10',
      );
    });

    test('UTC gece yarısından sonra yeni gün anahtarı üretir', () {
      expect(
        SupabaseZanKurdRepository.spinDayKey(DateTime.utc(2026, 7, 11, 0, 0)),
        '2026-7-11',
      );
      expect(
        SupabaseZanKurdRepository.spinDayKey(
          DateTime.utc(2026, 7, 10, 23, 59, 59),
        ),
        '2026-7-10',
      );
    });

    test('yerel DateTime girdisini UTC eşdeğerine çevirir', () {
      final local = DateTime(2026, 12, 31, 12, 0);
      expect(
        SupabaseZanKurdRepository.spinDayKey(local),
        SupabaseZanKurdRepository.spinDayKey(local.toUtc()),
      );
    });

    test('aynı UTC günü içinde sabit kalır (idempotent guard)', () {
      final morning = DateTime.utc(2026, 3, 5, 0, 1);
      final night = DateTime.utc(2026, 3, 5, 23, 58);
      expect(
        SupabaseZanKurdRepository.spinDayKey(morning),
        SupabaseZanKurdRepository.spinDayKey(night),
      );
    });
  });
}
