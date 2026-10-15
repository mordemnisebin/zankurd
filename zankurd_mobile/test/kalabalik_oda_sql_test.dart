import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kalabalık oda göçlerinin (`2026-10-16_kalabalik_oda.sql` ve
/// `2026-10-16_kalabalik_oda_odul.sql`) metin bekçisi.
///
/// ## Kusur
///
/// Bütün oda mantığı "tam 2 oyuncu" varsayıyordu ve özel oda ile hızlı eşleşme
/// odası birbirinden ayırt edilemiyordu; ayrıca host_left / stale_timeout /
/// opponent_not_ready / forfeit odalarında giriş ücreti ne ödül ne iade
/// oluyordu.
///
/// ## Neden sessizdi
///
/// Sunucu davranışı yerelde çalıştırılamıyor (Docker/Postgres yok). Bir sonraki
/// "temiz" yeniden yazım, eşleşme odasını koruyan `is_custom` kapısını, iade
/// anahtarını ya da `claim_quiz_reward`a dokunmama kuralını sessizce düşürebilir.
/// Bu test göçün sözleşmesini metin olarak sabitler.
void main() {
  final main = File('supabase/2026-10-16_kalabalik_oda.sql').readAsStringSync();
  final refund = File(
    'supabase/2026-10-16_kalabalik_oda_odul.sql',
  ).readAsStringSync();

  /// `create or replace function public.<name>(` ile başlayan gövde.
  String body(String source, String name) {
    final start = RegExp(
      'create or replace function public\\.$name\\(',
      caseSensitive: false,
    ).firstMatch(source);
    expect(start, isNotNull, reason: '$name göçte tanımlı olmalı');
    final open = source.indexOf(r'$function$', start!.start);
    final close = source.indexOf(r'$function$', open + 1);
    return source.substring(start.start, close);
  }

  test('sütunlar, kapasite sınırı ve eşleşme odası kısıtı', () {
    expect(
      main,
      contains(
        'add column if not exists is_custom boolean not null default false',
      ),
    );
    expect(
      main,
      contains(
        'add column if not exists max_players integer not null default 2',
      ),
    );
    expect(main, contains('add column if not exists left_at timestamptz'));
    expect(main, contains('check (max_players between 2 and 50)'));
    expect(main, contains('check (is_custom or max_players = 2)'));
  });

  test('create_online_room: izinli kapasiteler, eski imza düşer, grant', () {
    final fn = body(main, 'create_online_room');
    expect(fn, contains('p_max_players integer DEFAULT 2'));
    expect(fn, contains('p_max_players not in (2, 4, 8, 16, 30, 50)'));
    expect(fn, contains('is_custom,'));
    expect(
      main,
      contains(
        'drop function if exists public.create_online_room'
        '(text, integer, integer, integer);',
      ),
    );
    expect(
      main,
      contains(
        'grant execute on function public.create_online_room'
        '(text, integer, integer, integer, integer) to authenticated, service_role;',
      ),
    );
    expect(
      main,
      contains(
        'revoke all on function public.create_online_room'
        '(text, integer, integer, integer, integer) from public, anon;',
      ),
    );
  });

  test(
    'her fonksiyonda kalabalık kuralı is_custom ve max_players > 2 kapısında',
    () {
      const gated = [
        'join_room_by_code',
        'start_room_game',
        'mark_room_client_ready',
        'advance_room_question',
        'submit_answer',
        'enforce_current_room_question',
        'recalculate_room_player_scores',
        'leave_room',
        'cleanup_stale_rooms',
        'get_room_result_payload',
        'acknowledge_room_result',
        'delete_my_account',
      ];
      for (final name in gated) {
        final fn = body(main, name);
        expect(
          fn.contains('is_custom') && fn.contains('max_players > 2'),
          isTrue,
          reason:
              '$name kalabalık kuralını is_custom/max_players > 2 ile kapılamalı',
        );
      }
      // 2 kişilik özel oda eski yolda kalır: kapı ">= 2" değil "> 2".
      expect(main.contains('max_players >= 3'), isFalse);
    },
  );

  test('left_at: aktif oyuncu süzgeci ve yazan yerler', () {
    expect(body(main, 'join_room_by_code'), contains('rp.left_at is null'));
    expect(body(main, 'advance_room_question'), contains('rp.left_at is null'));
    expect(body(main, 'submit_answer'), contains('rp.left_at is null'));
    expect(body(main, 'get_my_resumable_room'), contains('rp.left_at is null'));
    expect(body(main, 'join_matchmaking'), contains('mine.left_at is null'));
    expect(body(main, 'crowd_room_member_leave'), contains('left_at = v_now'));
    expect(
      body(main, 'mark_room_client_ready'),
      contains('left_at = coalesce(rp.left_at, v_server_now)'),
    );
    expect(body(main, 'leave_room'), contains('crowd_room_member_leave'));
    expect(
      body(main, 'delete_my_account'),
      contains('crowd_room_member_leave'),
    );
  });

  test('beklenen cevap sayısı kalabalıkta aktif sayısı, eski odada 2', () {
    for (final name in ['advance_room_question', 'submit_answer']) {
      final fn = body(main, name);
      expect(fn, contains('v_expected'));
      expect(fn, contains('else 2'));
      expect(
        fn.contains('v_answer_count <> 2'),
        isFalse,
        reason: '$name sabit 2 yerine v_expected kullanmalı',
      );
    }
  });

  test(
    'start_room_game: kalabalıkta hazır şartı yok, 1v1 45 sn, kalabalık 20 sn',
    () {
      final fn = body(main, 'start_room_game');
      expect(fn, contains('if v_unready_count > 0 and not v_crowd then'));
      expect(fn, contains("interval '45 seconds'"));
      expect(fn, contains("interval '20 seconds'"));
      expect(
        fn,
        contains("raise exception 'Exactly two players are required'"),
      );
    },
  );

  test('1v1 canlılık değişiklikleri korunur', () {
    expect(body(main, 'join_matchmaking'), contains("interval '12 seconds'"));
    expect(body(main, 'join_matchmaking'), contains("interval '40 seconds'"));
    expect(body(main, 'touch_matchmaking'), contains('last_seen_at = now()'));
    expect(
      body(main, 'mark_room_client_ready'),
      contains("else interval '45 seconds'"),
    );
    expect(main.contains("interval '2 minutes'"), isFalse);
  });

  test(
    'iade: yardımcı odul dosyasında, benzersiz anahtar, çağrılar ana dosyada',
    () {
      expect(refund, contains("'room_entry_refund:room=' || p_room_id::text"));
      expect(refund, contains("':player=' || p_player_id::text"));
      expect(refund, contains('on conflict (player_id, reason)'));
      expect(refund, contains('coin_transactions_room_refund_uidx'));
      expect(
        refund,
        contains(
          'revoke all on function public.refund_room_entry_fees(uuid, uuid, boolean)',
        ),
      );
      expect(refund, contains('to service_role;'));
      expect(
        refund.contains('to authenticated'),
        isFalse,
        reason: 'iade yardımcıları istemciye açılmaz',
      );

      // Ana dosya yardımcılara bağımlıdır ve ön koşulu kendisi denetler.
      expect(main, contains('refund_room_entry_fees(uuid, uuid, boolean)'));
      expect(main, contains('kalabalik_oda_odul.sql'));
      expect(body(main, 'leave_room'), contains('refund_room_entry_fees'));
      expect(body(main, 'leave_room'), contains('refund_room_entry_fee('));
      expect(
        body(main, 'cleanup_stale_rooms'),
        contains('refund_room_entry_fees'),
      );
      expect(
        body(main, 'mark_room_client_ready'),
        contains('refund_room_entry_fees'),
      );
      expect(
        body(main, 'crowd_room_member_leave'),
        contains('refund_room_entry_fees'),
      );
    },
  );

  test('claim_quiz_reward ana dosyada YOK; odul dosyasında yalnız TODO', () {
    expect(
      main.contains('claim_quiz_reward'),
      isFalse,
      reason: 'ödül fonksiyonu başka dalda değişiyor; bu göçe girmez',
    );
    expect(refund.contains('function public.claim_quiz_reward'), isFalse);
    expect(refund, contains('TODO'));
    expect(refund, contains('claim_quiz_reward'));
    expect(refund, contains('%50'));
  });

  test('sonuç: rank eşitlikte paylaşılır, kalabalık tamlık yardımcısı', () {
    final players = body(main, 'room_result_players');
    expect(players, contains('rank() over'));
    expect(players, contains("'rank', ranked.player_rank"));
    expect(players, contains("'left', ranked.is_left"));
    expect(
      body(main, 'get_room_result_payload'),
      contains('room_result_players'),
    );
    expect(body(main, 'get_room_result_payload'), contains("'max_players'"));
    expect(
      body(main, 'acknowledge_room_result'),
      contains('crowd_room_result_complete'),
    );
    expect(
      body(main, 'delete_my_account'),
      contains('crowd_room_result_complete'),
    );
  });

  test('iç yardımcılar istemciye açılmaz', () {
    for (final sig in [
      'crowd_room_member_leave(uuid, uuid)',
      'room_result_players(uuid, uuid)',
      'room_result_winner(uuid, uuid)',
      'crowd_room_result_complete(uuid)',
    ]) {
      expect(
        main,
        contains(
          'revoke all on function public.$sig from public, anon, authenticated;',
        ),
      );
      expect(
        main,
        contains('grant execute on function public.$sig to service_role;'),
      );
    }
  });

  test('göçler idempotent ve tek işlemde', () {
    for (final sql in [main, refund]) {
      expect(sql, contains('begin;'));
      expect(sql.trimRight(), endsWith('commit;'));
    }
  });
}
