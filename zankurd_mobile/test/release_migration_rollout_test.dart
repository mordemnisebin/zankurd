import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// İstemcinin çağırdığı her RPC'nin göçü yayın runbook'unda yazmalı.
///
/// `2026-08-03_streak_freeze_idempotency.sql` yazıldı, yerel PostgreSQL'de
/// doğrulandı ve istemci ona geçirildi — ama `docs/YAYIN_ADIMLARI.md`
/// içinde ADI GEÇMİYORDU. Runbook tek operasyonel kaynak olduğu için,
/// onu izleyen biri göçü hiç uygulamadan yayına çıkardı: istemci
/// `PGRST202` alıp eski `spend_coins` yoluna düşer, dondurma çalışmaya
/// devam eder ama idempotent OLMAZ — yani göçün kapatmak için yazıldığı
/// çift-çekim penceresi sessizce açık kalır (2026-08-03 merge incelemesi).
///
/// Sessiz olması en kötü yanı: hiçbir şey kırılmadığı için kimse fark
/// etmez. Bekçi bu yüzden koda değil runbook'a bakar.
void main() {
  late String runbook;

  setUpAll(() {
    runbook = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
  });

  /// İstemcinin çağırdığı RPC → onu tanımlayan göç dosyası.
  const rpcToMigration = {
    'mark_room_client_ready': '2026-08-02_multiplayer_session_hardening.sql',
    'acknowledge_room_result': '2026-08-02_multiplayer_session_hardening.sql',
    'get_my_pending_room_result':
        '2026-08-02_multiplayer_session_hardening.sql',
    'spend_streak_freeze': '2026-08-03_streak_freeze_idempotency.sql',
  };

  test('istemcinin cagirdigi her yeni RPC gercekten cagriliyor', () {
    final repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    for (final rpc in rpcToMigration.keys) {
      expect(
        repo,
        contains("'$rpc'"),
        reason: '$rpc artik cagrilmiyorsa bu esleme guncellenmeli',
      );
    }
  });

  test('her gerekli goc yayin runbookunda adiyla geciyor', () {
    for (final entry in rpcToMigration.entries) {
      expect(
        runbook,
        contains(entry.value),
        reason:
            '${entry.value} runbookta yok; istemci ${entry.key} cagiriyor '
            've goc uygulanmadan yayina cikilirsa o yol sessizce bozulur',
      );
    }
  });

  test('goc-once sirasi runbookta yaziyor', () {
    // İstemci bu RPC'leri koşulsuz çağırıyor; göç uygulanmadan dağıtım
    // çevrimiçi maçı kırar. Sıra belgede açıkça durmalı.
    expect(runbook, contains('Kesim penceresinde sırayı değiştirme'));
  });

  test('uygulanmamis goc applied.md icinde YANLISLIKLA isaretli degil', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    for (final migration in rpcToMigration.values.toSet()) {
      final marked = RegExp(
        '^\\| ${RegExp.escape(migration)} \\| ✅',
        multiLine: true,
      ).hasMatch(applied);
      expect(
        marked,
        isFalse,
        reason:
            '$migration uretimde uygulanmadi; applied.md ✅ isareti '
            'yanlis guvence verir',
      );
    }
  });
}
