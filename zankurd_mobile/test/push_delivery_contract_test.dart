/// Bildirim teslimatı — göç + Edge Function sözleşmesi bekçisi.
///
/// ## Kusur
///
/// `push_outbox` kuyruğuna satır yazan SQL hazırdı ama FCM'e gönderen tek şey
/// elle çalıştırılan `tool/send_push_outbox.py` idi; hiçbir zamanlayıcı onu
/// çalıştırmıyordu. Canlıda yalnız üç cron işi vardı (cleanup-stale-rooms,
/// finalize-weekly-league, expire-async-duels). Sonuç: hiçbir bildirim
/// ulaşmıyordu, düello geri dönüş kancası ölüydü (2026-10-13).
///
/// ## Niçin sessiz kalırdı
///
/// Kuyruk satırları hatasız yazılır, `claimed_at` boş kalır, hiçbir test
/// kırılmaz — yalnız kullanıcıya bildirim gelmez. Göç ve fonksiyon CANLIYA
/// uygulanmadan metin olarak denetlenir (repo deseni: `async_duel_sql_contract_test.dart`).
/// Docker olmadığından göçün gerçek çalışması burada sınanmaz; uygulama
/// sırasında kendi doğrulama bloğu bunu yapar.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  late String fn;
  late String lib;

  setUpAll(() {
    sql = File('supabase/2026-10-13_push_delivery.sql').readAsStringSync();
    fn = File('supabase/functions/send-push/index.ts').readAsStringSync();
    lib = File('supabase/functions/send-push/lib.ts').readAsStringSync();
  });

  /// Satır içi `--` açıklamalarını atar: aşağıdaki "yok" denetimleri açıklama
  /// metnine takılmasın.
  String code(String text) =>
      text.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

  group('göç', () {
    test('send-push işi her dakika pg_net ile Vault sırlarından çağırır', () {
      expect(sql, contains("'send-push'"));
      expect(sql, contains("'* * * * *'"));
      expect(sql, contains('net.http_post'));
      expect(sql, contains("name = 'send_push_url'"));
      expect(sql, contains("name = 'cron_secret'"));
      expect(sql, contains("'x-cron-secret'"));
      expect(sql, contains('vault.decrypted_secrets'));
      // Yeniden kurulabilir: önce kaldırılır.
      expect(sql, contains("cron.unschedule('send-push')"));
    });

    test('hiçbir sır ya da proje adresi SQL içinde yazılı değil', () {
      final c = code(sql);
      expect(RegExp(r'https?://').hasMatch(c), isFalse);
      expect(c, isNot(contains('supabase.co')));
      expect(RegExp(r'eyJ[A-Za-z0-9_-]{10,}').hasMatch(c), isFalse);
      expect(c, isNot(contains('service_role_key')));
      expect(c.toLowerCase(), isNot(contains('create_secret')));
    });

    test('Vault sırrı ya da bekleyen satır yoksa komut no-op', () {
      final start = sql.indexOf(r'$cron$');
      final end = sql.lastIndexOf(r'$cron$');
      final command = sql.substring(start, end);
      // Üç koşul: iki Vault sırrı + gönderilmemiş satır.
      expect(command, contains("s.name = 'send_push_url'"));
      expect(command, contains("s.name = 'cron_secret'"));
      expect(command, contains('o.claimed_at is null'));
      expect(command, contains('where exists'));
    });

    test('davet bildirimi yaratıcının sonucunda, tek sefer kuyruklanır', () {
      expect(sql, contains('enqueue_async_duel_invite_push'));
      expect(sql, contains('after insert on public.async_duel_results'));
      expect(sql, contains('v_duel.invited_id is null'));
      expect(sql, contains('new.player_id <> v_duel.creator_id'));
      expect(sql, contains("'async_duel_invite'"));
      expect(sql, contains('blocked_users'));
      expect(
        sql,
        contains('drop trigger if exists trg_async_duel_invite_push'),
      );
    });

    test('davet metni iki dilli ve onaylanan Kurmancî ifadeyi taşır', () {
      expect(
        sql,
        contains(
          "'Dora te ye: ' || v_name || ' tu vexwendî pêşbirkê · Sıra sende: '",
        ),
      );
      expect(sql, contains("seni düelloya çağırdı"));
    });

    test('start/answer düello işlevleri bu göçte yeniden yazılmaz', () {
      final c = code(sql);
      expect(c, isNot(contains('function public.start_async_duel')));
      expect(c, isNot(contains('function public.answer_async_duel')));
    });

    test('clear_fcm_token yalnız service_role, tetikleyici işlevi kimseye', () {
      expect(
        sql,
        contains(
          'revoke all on function public.clear_fcm_token(uuid, text)\n'
          '  from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.clear_fcm_token(uuid, text) '
          'to service_role;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on function public.enqueue_async_duel_invite_push()\n'
          '  from public, anon, authenticated;',
        ),
      );
      // Jeton değişmişse (uygulama yeniledi) yenisini silme.
      expect(sql, contains('and fcm_token = p_token'));
      expect(sql, contains('security definer'));
      expect(sql, contains('set search_path = public'));
    });

    test('başlık sözleşmesi ve doğrulama bloğu var', () {
      for (final h in [
        'NİÇİN',
        'NE YAPAR',
        'TEKRAR',
        'GERİ ALMA',
        'Uygulama',
      ]) {
        expect(sql, contains(h));
      }
      expect(sql, contains('begin;'));
      expect(sql, contains('commit;'));
      expect(sql, contains('raise exception'));
      expect(sql, contains('select cron.unschedule'));
    });

    test('mevcut kuyruk işlevleri değişmedi (claim yalnız service_role)', () {
      final fcm = File('supabase/2026-08-26_fcm_token.sql').readAsStringSync();
      expect(
        fcm,
        contains(
          'revoke all on function public.claim_push_outbox(integer) '
          'from public, anon, authenticated;',
        ),
      );
    });
  });

  group('send-push Edge Function', () {
    test('x-cron-secret zorunlu, ortamdaki CRON_SECRET ile sabit-zamanlı', () {
      expect(fn, contains('x-cron-secret'));
      expect(fn, contains('CRON_SECRET'));
      expect(fn, contains('timingSafeEqual'));
      expect(fn, contains('"unauthorized"'));
      // Sır yapılandırılmamışsa kapı AÇIK kalmaz.
      expect(fn, contains('server_misconfigured'));
    });

    test('kuyruk service-role ile claim edilir, jeton temizlenir', () {
      expect(fn, contains('claim_push_outbox'));
      expect(fn, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(fn, contains('clear_fcm_token'));
      expect(fn, contains('BATCH_LIMIT = 50'));
      expect(fn, contains('FCM_SERVICE_ACCOUNT_JSON'));
      expect(
        fn,
        contains('https://www.googleapis.com/auth/firebase.messaging'),
      );
      expect(fn, contains('messages:send'));
    });

    test('OAuth jetonu kuyruktan ÖNCE alınır (hata satırları yakmaz)', () {
      expect(
        fn.indexOf('await accessToken(account)'),
        lessThan(fn.indexOf('admin.rpc("claim_push_outbox"')),
      );
    });

    test(
      'iletinin biçimi python betiğiyle uyumlu: notification + data.kind',
      () {
        expect(lib, contains('notification'));
        expect(lib, contains('data = { kind: job.kind }'));
        final py = File('tool/send_push_outbox.py').readAsStringSync();
        expect(py, contains('"kind"'));
        expect(py, contains('ELLE gönderir (yedek yol)'));
      },
    );

    test('günlüğe jeton ya da sır yazılmaz', () {
      // console.* çağrılarının argümanlarında jeton/anahtar değişkenleri yok.
      final calls = RegExp(
        r'console\.\w+\(([^;]*)\);',
        dotAll: true,
      ).allMatches(fn).map((m) => m.group(1)!).join('\n');
      expect(calls, isNotEmpty);
      for (final banned in [
        'token,',
        'bearer',
        'private_key',
        'assertion',
        'expected',
        'presented',
        'job.body',
        'job.title',
        'service_role',
      ]) {
        expect(
          calls,
          isNot(contains(banned)),
          reason: 'console.* içinde $banned',
        );
      }
    });

    test('config.toml bu fonksiyon için JWT doğrulamasını kapatır', () {
      final toml = File('supabase/config.toml').readAsStringSync();
      expect(toml, contains('[functions.send-push]'));
      expect(
        RegExp(
          r'\[functions\.send-push\]\s*\nverify_jwt = false',
        ).hasMatch(toml),
        isTrue,
      );
    });
  });

  test('applied.md send-push göçünü sahip adımlarıyla kaydeder', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    final row = RegExp(
      r'^\| 2026-10-13_push_delivery\.sql \| (?:⏳|✅) \|.*$',
      multiLine: true,
    ).firstMatch(applied);
    expect(row, isNotNull);
    final text = row!.group(0)!;
    for (final step in [
      'FCM_SERVICE_ACCOUNT_JSON',
      'CRON_SECRET',
      'supabase functions deploy send-push',
      'vault.create_secret',
      'send_push_url',
      'cron_secret',
    ]) {
      expect(text, contains(step));
    }
  });
}
