/// Sosyal yüzey + sertleştirme göçü — SQL sözleşmesi bekçisi.
///
/// ## Kusur
///
/// 2026-10-15 canlı denetimi on iki sessiz kusur buldu: istemci rollerinde
/// MAINTAIN, ölü bir görünüm, her biten odayı sayan (ve eşit puanda sırası
/// belirsiz) liderlik, her dakika yeniden damgalanan bitmiş turnuva, engelin
/// arkadaşlığı silmemesi, arkadaşı silme/isteği geri çekme yolunun olmaması,
/// yeniden gönderilen isteğin bildirim üretmemesi, iki profilde duran FCM
/// token'ı, sınırsız davet ödülü, sınırsız girdi boyutları ve yarım kalan
/// düelloya devam edilememesi.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: liderlik doğru görünür, engel "çalışır", istek
/// "gönderilir". Göç CANLIYA uygulanmadan metin olarak denetlenir (repo
/// deseni: `push_delivery_contract_test.dart`); Docker olmadığından göçün gerçek
/// çalışması burada sınanmaz, uygulama sırasındaki doğrulama bloğu bunu yapar.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/2026-10-15_sosyal_ve_sertlestirme.sql',
    ).readAsStringSync();
  });

  /// Yorum satırlarını atar: "yok" denetimleri açıklama metnine takılmasın.
  String code(String text) =>
      text.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

  /// `create or replace function public.<name>(` ile başlayıp gövdenin
  /// kapanış `$function$` işaretine kadar olan metin (başlık dahil).
  String body(String name) {
    final start = sql.indexOf('create or replace function public.$name(');
    expect(start, isNonNegative, reason: '$name tanımı yok');
    final open = sql.indexOf(r'$function$', start);
    final close = sql.indexOf(r'$function$', open + 1);
    expect(close, greaterThan(open), reason: '$name gövdesi kapanmıyor');
    return sql.substring(start, close);
  }

  test('tek işlem: begin ... commit ve doğrulama bloğu', () {
    expect(sql, contains('\nbegin;\n'));
    expect(sql.trimRight().endsWith('commit;'), isTrue);
    expect(sql, contains('sosyal_sertlestirme: '));
  });

  group('yetki', () {
    test('questions ve player_answers MAINTAIN yetkisi alınır', () {
      expect(
        sql,
        contains(
          'revoke maintain on public.questions, public.player_answers\n'
          '  from anon, authenticated;',
        ),
      );
    });

    test('ölü görünüm silinir ve istemci çağrısı kalmaz', () {
      expect(
        sql,
        contains('drop view if exists public.quiz_public_questions;'),
      );
      final repo = File(
        'lib/src/data/supabase_zankurd_repository.dart',
      ).readAsStringSync();
      expect(repo, isNot(contains("from('quiz_public_questions')")));
    });

    test('yeni RPC\'ler anon\'a kapalı, authenticated\'a açık', () {
      for (final fn in [
        'remove_friend(uuid)',
        'cancel_friend_request(uuid)',
        'list_sent_friend_requests()',
        'clear_my_fcm_token()',
        'resume_my_async_duel(uuid)',
        'cancel_my_async_duel(uuid)',
      ]) {
        expect(
          sql,
          contains('revoke all on function public.$fn from public, anon;'),
          reason: fn,
        );
        expect(
          sql,
          contains('grant execute on function public.$fn to authenticated'),
          reason: fn,
        );
      }
      expect(
        sql,
        contains(
          'revoke all on function public.sever_social_ties(uuid, uuid)\n'
          '  from public, anon, authenticated;',
        ),
      );
    });

    test('değiştirilen her fonksiyon SECURITY DEFINER + sabit search_path', () {
      for (final name in [
        'get_leaderboard',
        'get_my_leaderboard_rank',
        'advance_tournament',
        'block_player',
        'report_player_profile',
        'add_friend',
        'set_fcm_token',
        'redeem_referral_code',
        'log_analytics_event',
        'start_async_duel',
        'create_async_duel_challenge',
        'remove_friend',
        'cancel_friend_request',
        'list_sent_friend_requests',
        'clear_my_fcm_token',
        'resume_my_async_duel',
        'cancel_my_async_duel',
        'sever_social_ties',
      ]) {
        final fn = body(name);
        expect(fn, contains('security definer'), reason: name);
        expect(fn, contains("set search_path to 'public'"), reason: name);
      }
    });
  });

  group('liderlik', () {
    test(
      'yalnız normal biten odalar sayılır, eşitlikte player_id bağ kırar',
      () {
        final list = body('get_leaderboard');
        final rank = body('get_my_leaderboard_rank');
        for (final fn in [list, rank]) {
          expect(
            fn,
            contains("coalesce(r.ended_reason, 'completed') = 'completed'"),
          );
        }
        expect(list, contains('rp.player_id asc'));
        expect(rank, contains('b.player_id asc'));
      },
    );
  });

  test('advance_tournament bitmiş turnuvaya dokunmaz', () {
    final fn = body('advance_tournament');
    final guard = fn.indexOf("status = 'finished'");
    final stamp = fn.indexOf('finished_at = now()');
    expect(guard, isNonNegative);
    expect(stamp, isNonNegative);
    expect(guard, lessThan(stamp), reason: 'koruma damgadan önce olmalı');
  });

  group('engel', () {
    test('iç yardımcı iki yönde arkadaşlık ve istekleri siler', () {
      final fn = body('sever_social_ties');
      expect(fn, contains('delete from public.friends'));
      expect(fn, contains('delete from public.friend_requests'));
      expect(fn, contains('user_id = p_a and friend_id = p_b'));
      expect(fn, contains('user_id = p_b and friend_id = p_a'));
      expect(fn, contains('from_user_id = p_a and to_user_id = p_b'));
      expect(fn, contains('from_user_id = p_b and to_user_id = p_a'));
    });

    test('block_player ve report_player_profile yardımcıyı çağırır', () {
      expect(body('block_player'), contains('public.sever_social_ties('));
      expect(
        body('report_player_profile'),
        contains('public.sever_social_ties('),
      );
    });
  });

  group('arkadaşlık yaşam döngüsü', () {
    test('remove_friend iki yönü siler', () {
      final fn = body('remove_friend');
      expect(fn, contains('delete from public.friends'));
      expect(fn, contains('user_id = v_uid and friend_id = p_friend_id'));
      expect(fn, contains('user_id = p_friend_id and friend_id = v_uid'));
      expect(fn, contains('auth.uid()'));
    });

    test('cancel_friend_request yalnız kendi bekleyen isteğini iptal eder', () {
      final fn = body('cancel_friend_request');
      expect(fn, contains("set status = 'cancelled'"));
      expect(fn, contains('from_user_id = v_uid'));
      expect(fn, contains("status = 'pending'"));
      // Silseydik hız sınırı (created_at) iptal-yeniden gönder ile aşılırdı.
      expect(code(fn), isNot(contains('delete from')));
    });

    test('add_friend: karşılıklı kabul, profil denetimi, hız sınırı', () {
      final fn = body('add_friend');
      expect(fn, contains('Friend request accepted'));
      expect(fn, contains('from_user_id = p_friend_id'));
      expect(fn, contains('Friend not found'));
      expect(fn, contains('Too many friend requests'));
      expect(fn, contains(">= 30"));
      expect(fn, contains("interval '24 hours'"));
      expect(fn, contains('Friend request cooldown'));
      // Eski dönüş sözleşmesi korunur.
      expect(fn, contains('Friend request sent'));
      expect(fn, contains('Already friends'));
      expect(fn, contains('Friend request blocked'));
    });

    test(
      'yeniden gönderilen istek de bildirim üretir (UPDATE tetikleyicisi)',
      () {
        expect(
          sql,
          contains(
            'create trigger trg_friend_request_push_resend\n'
            '  after update of status on public.friend_requests',
          ),
        );
        expect(
          sql,
          contains(
            "when (old.status is distinct from 'pending' "
            "and new.status = 'pending')",
          ),
        );
        expect(
          sql,
          contains('execute function public.enqueue_friend_request_push();'),
        );
      },
    );
  });

  group('FCM token', () {
    test('set_fcm_token token\'ı başka profillerden siler', () {
      final fn = body('set_fcm_token');
      final clear = fn.indexOf('where fcm_token = v_token and id <> v_uid');
      final set = fn.indexOf('set fcm_token = v_token where id = v_uid');
      expect(clear, isNonNegative);
      expect(set, greaterThan(clear), reason: 'önce temizle, sonra ata');
    });

    test('clear_my_fcm_token ve 4096 sınırı', () {
      expect(body('clear_my_fcm_token'), contains('auth.uid()'));
      expect(sql, contains('char_length(fcm_token) <= 4096'));
      expect(sql, contains('validate constraint profiles_fcm_token_len'));
    });
  });

  group('davet ödülü', () {
    test('davet eden başına 10 ödül ve oynamış hesap şartı', () {
      final fn = body('redeem_referral_code');
      expect(fn, contains('v_referrer_cap constant integer := 10'));
      expect(fn, contains("'limit_reached'"));
      expect(fn, contains("'not_active'"));
      expect(fn, contains("ct.reason = 'solo_round'"));
      expect(fn, contains("ct.reason like 'quiz_complete:%'"));
      expect(fn, contains("r.ended_reason = 'completed'"));
      // Sınır/şart ödül yazımından ÖNCE.
      expect(
        fn.indexOf("'not_active'"),
        lessThan(fn.indexOf('insert into public.referral_redemptions')),
      );
    });
  });

  group('girdi boyutu', () {
    test('suggested_questions uzunluk kısıtları', () {
      expect(sql, contains('char_length(prompt) <= 500'));
      expect(sql, contains('char_length(option_a) <= 200'));
      expect(sql, contains('char_length(option_d) <= 200'));
      expect(sql, contains('char_length(explanation) <= 1000'));
    });

    test('log_analytics_event ad ve parametre sınırı', () {
      final fn = body('log_analytics_event');
      expect(fn, contains('char_length(p_event_name) > 64'));
      expect(fn, contains('octet_length(p_event_params::text) > 4096'));
      expect(fn, contains('raise exception'));
    });
  });

  group('sırayla düello', () {
    test('açık düello sayımı süresi dolanı saymaz (iki giriş noktası)', () {
      for (final name in ['start_async_duel', 'create_async_duel_challenge']) {
        final fn = body(name);
        final count = fn.indexOf('select count(*) into v_open_count');
        expect(count, isNonNegative, reason: name);
        final window = fn.substring(
          count,
          fn.indexOf('Too many open duels', count),
        );
        expect(window, contains('expires_at > now()'), reason: name);
      }
    });

    test('resume_my_async_duel yeniden-açılış yanıtını döndürür', () {
      final fn = body('resume_my_async_duel');
      expect(fn, contains("'answered', v_answered"));
      expect(fn, contains("'finished', v_finished"));
      expect(fn, contains('async_duel_questions_payload'));
      expect(fn, contains('Duel expired'));
      expect(fn, contains('creator_id <> v_uid'));
    });

    test(
      'cancel_my_async_duel yalnız yaratıcı, yalnız katılımsız açık düello',
      () {
        final fn = body('cancel_my_async_duel');
        expect(fn, contains('creator_id <> v_uid'));
        expect(fn, contains('opponent_id is not null'));
        expect(fn, contains("status <> 'open'"));
        expect(fn, contains("set status = 'expired'"));
        expect(code(fn), isNot(contains('delete from')));
      },
    );
  });

  test('applied.md satırı ⏳ ve dosya adını taşır', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(applied, contains('| 2026-10-15_sosyal_ve_sertlestirme.sql | '));
  });
}
