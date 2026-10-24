import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

// Regression: günlük çark guard'ı sunucudaki `public.app_today()`
// (`Europe/Istanbul`, kalıcı UTC+3) ile aynı gün sınırını kullanmalı
// (`2026-10-15_ilerleme_esitleme.sql`). Cihazın yerel saat diliminden bağımsız
// olarak UTC+3 gece yarısında yeni güne geçer; aksi halde TSİ 00:00-03:00
// arasında sunucuda yeni gün başladığı halde istemci eski UTC gününde kalarak
// çarkı kilitler.
void main() {
  group('SupabaseZanKurdRepository.spinDayKey', () {
    test(
      'Europe/Istanbul (UTC+3) gününü kullanır, cihaz saat diliminden etkilenmez',
      () {
        // UTC 22:30 = TSİ (UTC+3) 11 Temmuz 01:30 -> İstanbul'da 11 Temmuz.
        final istanbulAfterMidnight = DateTime.utc(2026, 7, 10, 22, 30);
        expect(
          SupabaseZanKurdRepository.spinDayKey(istanbulAfterMidnight),
          '2026-7-11',
        );
      },
    );

    test(
      'İstanbul gece yarısından (21:00 UTC) sonra yeni gün anahtarı üretir',
      () {
        expect(
          SupabaseZanKurdRepository.spinDayKey(
            DateTime.utc(2026, 7, 10, 21, 0, 0),
          ),
          '2026-7-11',
        );
        expect(
          SupabaseZanKurdRepository.spinDayKey(
            DateTime.utc(2026, 7, 10, 20, 59, 59),
          ),
          '2026-7-10',
        );
      },
    );

    test('yerel DateTime girdisini UTC+3 eşdeğerine çevirir', () {
      final local = DateTime(2026, 12, 31, 12, 0);
      expect(
        SupabaseZanKurdRepository.spinDayKey(local),
        SupabaseZanKurdRepository.spinDayKey(local.toUtc()),
      );
    });

    test('aynı İstanbul günü içinde sabit kalır (idempotent guard)', () {
      // TSİ 00:01 (UTC 21:01 önceki gün) ile TSİ 23:58 (UTC 20:58 aynı gün)
      final morning = DateTime.utc(2026, 3, 4, 21, 1);
      final night = DateTime.utc(2026, 3, 5, 20, 58);
      expect(
        SupabaseZanKurdRepository.spinDayKey(morning),
        SupabaseZanKurdRepository.spinDayKey(night),
      );
    });
  });
}
