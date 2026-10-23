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
    // Lobi: 30 dk, etkinlik = katılım + sohbet + davet (+ kuruluş).
    expect(body, contains("interval '30 minutes'"));
    expect(body, isNot(contains("interval '15 minutes'")));
    expect(body, contains('max(rp.joined_at)'));
    expect(body, contains('public.room_messages'));
    expect(body, contains('public.room_invites'));
    // Aktif oda: 10 dk etkinliksizlik.
    expect(body, contains("interval '10 minutes'"));
    expect(body, isNot(contains("interval '24 hours'")));
    expect(body, contains('max(pa.created_at)'));
    expect(body, contains('max(rq.revealed_at)'));
    expect(body, contains("ended_reason = 'stale_timeout'"));
    // Son soru açıklanmış bayat oda 'completed' biter, stale değil.
    expect(body, contains('as final_revealed'));
    expect(
      body,
      contains("elsif v_room.status = 'active' and v_room.final_revealed"),
    );
    expect(
      body.indexOf("ended_reason = 'completed'"),
      lessThan(body.lastIndexOf("ended_reason = 'stale_timeout'")),
      reason: 'completed dalı stale dalından önce gelmeli',
    );
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
    // Düşürme: yaş (kind null = diğer) ve engel, sınırlı.
    expect(claim, contains("coalesce(d.kind, '') = 'room_invite'"));
    expect(claim, contains("interval '30 minutes'"));
    expect(claim, contains("interval '24 hours'"));
    expect(claim, contains('public.blocked_users'));
    expect(claim, contains('d.from_user_id is not null'));
    expect(claim, contains('limit 500'));
    // Seçim: token'ı olan profil + aynı yaş/engel koşulları; işaretleme
    // profil JOIN'inden SONRA (token'sız bildirim yanmaz).
    expect(claim, contains('join public.profiles pr on pr.id = o.to_user_id'));
    expect(claim, contains("nullif(pr.fcm_token, '') is not null"));
    expect(claim, contains('o.from_user_id is not null'));
    expect(claim, contains('for update of o skip locked'));
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

  test('S4: görev ödülü sunucu eşlemesinden, anahtar beyaz listeli', () {
    final body = fn('sync_mission_completion');
    // İstemci değerleri yok sayılır: ekleme sunucu sabitlerini kullanır.
    expect(body, isNot(contains('p_coin_reward,')));
    expect(
      body,
      contains('VALUES (v_user_id, p_mission_key, v_today, v_coin, 100)'),
    );
    expect(body, contains('ELSE NULL'));
    expect(body, contains('IF v_coin IS NULL THEN'));
    expect(body, contains('IF v_rows < 3 THEN'));
    expect(body, contains('public.mission_completions'));
    expect(body, isNot(contains(' mission_completions mc')));

    // 14 şablonun anahtarı istemci modelinden (pool) çıkar ve eşlemede olmalı.
    final model = File('lib/src/models/daily_mission.dart').readAsStringSync();
    final pool = model.substring(
      model.indexOf('static const List<MissionDef> pool'),
    );
    final defs = RegExp(
      r'MissionDef\(\s*type: MissionType\.(\w+),\s*target: (\d+),\s*coinReward: (\d+)'
      r"(?:,\s*category: '([^']+)')?",
    ).allMatches(pool.substring(0, pool.indexOf('];')));
    const slugs = {
      'Ziman': 'ziman',
      'Çand': 'cand',
      'Dîrok': 'dirok',
      'Edebiyat': 'edebiyat',
      'Cografya': 'cografya',
      'Muzîk': 'muzik',
    };
    var count = 0;
    for (final m in defs) {
      final type = m.group(1)!;
      final key = type == 'playCategory'
          ? 'playCategory:${slugs[m.group(4)]}'
          : '$type:${m.group(2)}';
      expect(
        body,
        contains("WHEN '$key' THEN ${m.group(3)}"),
        reason: '$key eşlemede ve şablonun jetonuyla olmalı',
      );
      count++;
    }
    expect(count, 14, reason: 'havuzda 14 görev şablonu var');
  });

  test('S5: analitik olay saatte 600 ile sınırlı', () {
    final body = fn('log_analytics_event');
    expect(body, contains("interval '1 hour'"));
    expect(body, contains('limit 600'));
    expect(body, contains('v_recent >= 600'));
    expect(body, contains('public.analytics_events'));
    expect(body, isNot(contains(' analytics_events e')));
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

  test('yetki: iç fonksiyonlar açıkça kapalı, search_path pg_temp taşır', () {
    expect(
      sql,
      contains(
        'revoke execute on function public.claim_push_outbox(integer) '
        'from public, anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke execute on function public.cleanup_stale_rooms() '
        'from public, anon, authenticated;',
      ),
    );
    for (final name in [
      'leave_room',
      'cleanup_stale_rooms',
      'claim_push_outbox',
      'enqueue_friend_request_push',
      'enqueue_friend_accept_push',
      'invite_friends_to_room',
      'sync_mission_completion',
      'log_analytics_event',
      'finalize_weekly_league',
    ]) {
      expect(
        fn(name),
        contains("SET search_path TO 'public', 'pg_temp'"),
        reason: '$name SECURITY DEFINER gövdesi pg_temp ile sabitlenmeli',
      );
    }
    expect(sql, isNot(contains("SET search_path TO 'public'\n")));
  });

  test(
    'kanıt betiği begin ile açılır, rollback ile kapanır, tüm bulguları kapsar',
    () {
      final proof = File(proofPath).readAsStringSync();
      expect(proof, contains('\nbegin;\n'));
      expect(proof.trimRight(), endsWith('rollback;'));
      expect(proof, isNot(contains('commit;')));
      for (final s in [
        'S1a',
        'S1c',
        'S2c',
        'S2e',
        'S2g',
        'S3b',
        'S3f',
        'S4a',
        'S4b',
        'S4c',
        'S5',
        'S6a',
        'Y1',
        'Y4',
      ]) {
        expect(proof, contains(s), reason: 'kanıt betiği $s satırını basmalı');
      }
    },
  );
}
