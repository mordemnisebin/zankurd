/// 2026-10-24 sunucu sertleştirme göçü — sözleşme bekçisi.
///
/// ## Kusur
///
/// Altı sunucu kusuru sessizdi: (S1) 1v1'de son açıklamadan sonra çıkan
/// oyuncu odayı 'forfeit' bitirip kazananın XP/jeton/lig puanını siliyordu;
/// (S2) hayalet lobi/aktif oda oyuncuyu 24 saat kilitliyordu; (S3) push
/// kuyruğu, alıcı gönderen engelledikten sonra da bildirim yolluyordu ve
/// eski satırlara yaş sınırı yoktu; (S4) görev ödülü istemciden sınırsız
/// geliyordu; (S5) analitik olayına hız sınırı yoktu; (S6) lig kapanışının
/// son dosya tanımı `ended_reason = 'completed'` süzgecini kaybetmişti.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri istemcide görünmez; sunucu fonksiyonlarının gövdesi yalnız
/// `create or replace` ile değişir ve en son tanım kazanır. Sonraki bir göç
/// eski gövdeyi kopyalarsa düzeltme sessizce geri gider.
///
/// ## Kural
///
/// Göç her düzeltmeyi taşır ve kanıt betiği (begin…rollback) ÖNCE/SONRA
/// çalıştırılmak üzere repoda durur. Bu fonksiyonları yeniden tanımlayan
/// sonraki göç, aşağıdaki işaretleri korumalıdır.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath = 'supabase/2026-10-24_sunucu_sertlestirme.sql';
  const proofPath = 'supabase/kanit/2026-10-24_sunucu_sertlestirme_kanit.sql';

  late String sql;
  setUpAll(() => sql = File(migrationPath).readAsStringSync());

  /// `create or replace function public.<name>` ile başlayan bloğun gövdesi.
  String fn(String name) {
    final start = RegExp(
      'create or replace function public\\.$name\\(',
      caseSensitive: false,
    ).firstMatch(sql);
    expect(start, isNotNull, reason: '$name göçte tanımlı olmalı');
    // İlk $function$ açılış, ikincisi kapanış.
    final open = sql.indexOf(r'$function$', start!.end);
    final close = sql.indexOf(r'$function$', open + 10);
    expect(close, greaterThan(open), reason: '$name gövdesi kapanmalı');
    return sql.substring(start.start, close);
  }

  test('göç tek transaction ve commit ile biter', () {
    expect(sql, contains('\nbegin;\n'));
    expect(sql.trimRight(), endsWith('commit;'));
  });

  test('S1: leave_room son açıklamadan sonra completed bitirir', () {
    final body = fn('leave_room');
    expect(body, contains('v_final_revealed'));
    expect(body, contains('bool_and(rq.revealed_at is not null)'));
    expect(body, contains("ended_reason = 'completed'"));
    expect(body, contains('current_question_index = r.question_count'));
    // Eski terk yolu hâlâ duruyor (son soru açıklanmadıysa).
    expect(body, contains("ended_reason = 'forfeit'"));
    expect(
      body.indexOf("ended_reason = 'completed'"),
      lessThan(body.indexOf("ended_reason = 'forfeit'")),
      reason: 'completed dalı forfeit dalından önce denetlenmeli',
    );
  });

  test('S2: bayat oda zaman aşımları ve 5 dakikalık cron', () {
    final body = fn('cleanup_stale_rooms');
    expect(body, contains("interval '15 minutes'"));
    expect(body, contains("interval '10 minutes'"));
    expect(body, isNot(contains("interval '24 hours'")));
    expect(body, contains('max(pa.created_at)'));
    expect(body, contains('max(rq.revealed_at)'));
    expect(body, contains("ended_reason = 'stale_timeout'"));
    expect(sql, contains("cron.unschedule('cleanup-stale-rooms')"));
    expect(sql, contains("'*/5 * * * *'"));
  });

  test('S3: push_outbox gönderen sütunu, yaş sınırı ve engel süzgeci', () {
    expect(
      sql,
      contains(
        'alter table public.push_outbox add column if not exists from_user_id uuid',
      ),
    );
    final claim = fn('claim_push_outbox');
    expect(claim, contains("d.kind = 'room_invite'"));
    expect(claim, contains("interval '30 minutes'"));
    expect(claim, contains("interval '24 hours'"));
    expect(claim, contains('public.blocked_users'));
    expect(claim, contains('d.from_user_id is not null'));
    for (final trigger in [
      'enqueue_friend_request_push',
      'enqueue_friend_accept_push',
      'invite_friends_to_room',
    ]) {
      expect(
        fn(trigger),
        contains('from_user_id'),
        reason: '$trigger gönderen kimliğini yazmalı',
      );
    }
    // Async düello tetikleyicisine bu göçte dokunulmaz.
    expect(
      sql,
      isNot(contains('function public.enqueue_async_duel_invite_push')),
    );
  });

  test('S4: görev ödülü sınırlı', () {
    final body = fn('sync_mission_completion');
    expect(
      body,
      contains('least(greatest(coalesce(p_coin_reward, 0), 0), 100)'),
    );
    expect(body, contains('least(greatest(coalesce(p_xp_reward, 0), 0), 100)'));
  });

  test('S5: analitik olay saatte 600 ile sınırlı', () {
    final body = fn('log_analytics_event');
    expect(body, contains("interval '1 hour'"));
    expect(body, contains('limit 600'));
    expect(body, contains('v_recent >= 600'));
  });

  test('S6: lig kapanışı completed süzgecini ve yetki geri almayı taşır', () {
    final body = fn('finalize_weekly_league');
    expect(body, contains("r.ended_reason = 'completed'"));
    expect(
      sql,
      contains(
        'revoke execute on function public.finalize_weekly_league(date) '
        'from public, anon, authenticated;',
      ),
    );
  });

  test(
    'kanıt betiği begin ile açılır, rollback ile kapanır, tüm bulguları kapsar',
    () {
      final proof = File(proofPath).readAsStringSync();
      expect(proof, contains('\nbegin;\n'));
      expect(proof.trimRight(), endsWith('rollback;'));
      expect(proof, isNot(contains('commit;')));
      for (final s in ['S1a', 'S2a', 'S3b', 'S4', 'S5', 'S6a']) {
        expect(proof, contains(s), reason: 'kanıt betiği $s satırını basmalı');
      }
    },
  );
}
