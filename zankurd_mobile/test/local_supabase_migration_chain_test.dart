import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `supabase start` temiz bir makinede production şema geçmişini yeniden
/// kurabilmeli. Production migration history'de kayıtlı baseline dosyaları
/// `supabase/migrations/` dışında kalırsa CLI yalnız sonraki ALTER'ı çalıştırır
/// ve ilk `public.rooms` erişiminde kırılır.
void main() {
  const canonicalBaselines = <String>[
    '20260801000000_production_baseline.sql',
    '20260802000000_multiplayer_session_hardening.sql',
    '20260803000000_streak_freeze_idempotency.sql',
    '20260806000001_neon_frame_persistence.sql',
    '20260806000002_friend_identity_and_resend.sql',
    '20260806000003_profile_insert_and_league_authority.sql',
  ];

  test('production baseline migrationları yerel execution rootunda mevcut', () {
    for (final name in canonicalBaselines) {
      final canonical = File('supabase/baselines/$name');
      final runnable = File('supabase/migrations/$name');
      expect(canonical.existsSync(), isTrue, reason: '$name canonical eksik');
      expect(
        runnable.existsSync(),
        isTrue,
        reason:
            '$name migrations/ altında değilse temiz `supabase start` '
            'şemayı kuramaz.',
      );
      expect(
        runnable.readAsBytesSync(),
        canonical.readAsBytesSync(),
        reason: '$name doğrulanmış canonical baseline ile birebir olmalı.',
      );
    }
  });

  test('11 Ağustos lisans migrationı yerel zincirde kayıtlı', () {
    final migration = File(
      'supabase/migrations/20260811000000_suggested_question_license_guard.sql',
    );
    expect(
      migration.existsSync(),
      isTrue,
      reason:
          'Remote migration history bu sürümü içeriyor; yerelde eksik kalırsa '
          'fresh bootstrap production geçmişinden sapar.',
    );
    final source = migration.readAsStringSync();
    expect(source, contains("license_version = '2026-08-11'"));
    expect(source, contains('stamp_suggested_question_acceptance'));
    expect(source, contains('do_not_publish'));
    expect(source, contains('attribution_requested'));
  });

  test('remote migration geçmişi applied ledger ile çelişmez', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(
      applied,
      contains('| 20260811000000_suggested_question_license_guard.sql | ✅ |'),
      reason: 'Remote migration list bu sürümü uygulanmış gösteriyor.',
    );
    expect(
      applied,
      contains('20260819000000_gamification_and_custom_rooms.sql history gap'),
      reason:
          '19 Ağustos şeması canlıda uygulanmış olsa da remote migration '
          'history bu timestampi taşımıyor; db push öncesi bu risk görünür olmalı.',
    );
    expect(applied, contains('supabase migration repair'));
    expect(applied, contains('supabase db push'));
  });
}
