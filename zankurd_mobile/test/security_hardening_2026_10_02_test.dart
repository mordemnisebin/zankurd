import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-10-02 güvenlik denetimi göçlerinin sözleşme bekçisi.
///
/// Canlı veritabanına dokunmaz; göç dosyalarının NİÇİN yazıldığını koruyan
/// kalıpları ve mağazadaki eski istemcinin bağımlı olduğu yüzeyi sabitler.
/// Her blok, kusurun ne olduğunu ve niçin sessiz kaldığını anlatır.
String _sql(String name) => File('supabase/$name').readAsStringSync();

void main() {
  const files = [
    '2026-10-02_grants_hardening.sql',
    '2026-10-02_referral_redemption_ledger.sql',
    '2026-10-02_tournament_reward_server_validated.sql',
    '2026-10-02_room_reward_daily_cap.sql',
    '2026-10-02_report_hardening.sql',
    '2026-10-02_blocking_enforcement.sql',
    '2026-10-02_async_duel_server_timing.sql',
    '2026-10-02_apple_auth_tokens.sql',
  ];

  group('her göç tek işlemde, doğrulamalı ve uygulama kaydında ⏳', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    for (final name in files) {
      test(name, () {
        final sql = _sql(name);
        expect(sql.trimLeft(), startsWith('--'), reason: 'Türkçe başlık');
        expect(sql, contains('\nbegin;'));
        expect(sql.trimRight(), endsWith('commit;'));
        expect(sql, contains('raise exception'), reason: 'doğrulama bloğu');
        expect(sql, contains('GERİ ALMA'), reason: 'geri alma notu');
        expect(
          RegExp('^\\| $name \\| (⏳|✅) \\|', multiLine: true).hasMatch(applied),
          isTrue,
          reason: 'applied.md satırı yok',
        );
      });
    }
  });

  test('H1: referred_by istemciden yazılamaz ve ödül kayıt tablosuna bağlı', () {
    final sql = _sql('2026-10-02_referral_redemption_ledger.sql');
    // Kusur: `referred_by` korumasızdı; istemci NULL'layıp RPC'yi tekrar
    // çağırarak her seferinde 100+100 coin bastırabiliyordu.
    expect(sql, contains('new.referred_by := old.referred_by;'));
    expect(sql, contains('new.referred_by := null;'));
    expect(sql, contains('primary key references public.profiles'));
    expect(sql, contains('insert into public.referral_redemptions'));
    expect(sql, contains('on conflict (user_id) do nothing'));
    expect(sql, contains('get diagnostics v_rows = row_count'));
    // Ödül ekleme satırı, kayıt tablosuna girişten SONRA gelmeli.
    expect(
      sql.indexOf(
        'insert into public.referral_redemptions (user_id, referrer_id)',
      ),
      lessThan(sql.indexOf("'referral_welcome'),\n    (v_referrer.id")),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.referral_redemptions from public, anon, authenticated',
      ),
    );
    // İmza korunur (eski istemci).
    expect(sql, contains('redeem_referral_code(p_code text)'));
    expect(sql, contains('returns jsonb'));
  });

  test('H2: eski istemci turnuva RPC\'lerini çağırdığı için revoke YOK', () {
    final sql = _sql('2026-10-02_tournament_reward_server_validated.sql');
    expect(
      sql,
      contains('scores_server_validated boolean not null default false'),
    );
    expect(sql, contains('and t.scores_server_validated'));
    // Eski istemci (468ea4a4) join/bracket/claim çağırır; EXECUTE alınırsa
    // hata ekranı çıkar. authenticated'a geri verilir, kapatılmaz.
    expect(
      sql,
      contains(
        'grant execute on function public.claim_tournament_reward() to authenticated',
      ),
    );
    expect(
      sql,
      isNot(contains('revoke all on function public.submit_tournament_match')),
    );
    expect(
      sql,
      isNot(contains('revoke all on function public.join_tournament')),
    );
    // Ödül tutarı ve defter anahtarı değişmedi.
    expect(sql, contains("'tournament_champion:'"));
    expect(sql, contains('values (v_uid, 200, v_reason)'));
  });

  test('M3: oda ödülünün performans kısmı günde 300 coin ile sınırlı', () {
    final sql = _sql('2026-10-02_room_reward_daily_cap.sql');
    expect(sql, contains('v_daily_cap constant integer := 300'));
    expect(sql, contains('room_reward_daily'));
    // Bahis payı tavana girmez (oyuncunun kendi parası).
    expect(sql, contains('v_amount := v_base_paid;'));
    // Oda başına tek ödül (idempotency) aynen duruyor.
    expect(sql, contains("'quiz_complete:room=' || p_room_id::text"));
    expect(sql, contains("'already_claimed', true"));
    // Eski imza: 5 parametre, hepsi DEFAULT'lu.
    expect(sql, contains('p_room_id uuid default null'));
    expect(sql, contains('p_total_questions integer default 0'));
  });

  test('M4: düello süresi sunucuda ölçülür, istemci değeri kullanılmaz', () {
    final sql = _sql('2026-10-02_async_duel_server_timing.sql');
    expect(sql, contains('v_server_ms'));
    expect(sql, contains('max(a.answered_at)'));
    expect(
      sql,
      contains("when p_choice = 'TIMEOUT' then v_max_ms else v_server_ms"),
    );
    final functionBody = sql.substring(0, sql.indexOf('do \$\$'));
    expect(functionBody, isNot(contains('least(coalesce(p_response_ms')));
    // İmza korunur; yalnız v_response_ms sunucu değerinden gelir.
    expect(
      sql,
      contains(
        'answer_async_duel(p_duel_id uuid, p_question_index integer, p_choice text, p_response_ms integer)',
      ),
    );
    // Doğru şık davranışı bilerek değişmedi; gerekçe belgede.
    expect(sql, contains("'correct_option', v_correct_option"));
    expect(sql, contains('DEĞİŞTİRİLMEDİ'));
  });

  test('M5: engel yedi yolda uygulanır, yeni hata metni uydurulmaz', () {
    final sql = _sql('2026-10-02_blocking_enforcement.sql');
    for (final fn in [
      'join_room_by_code',
      'add_friend',
      'accept_friend_request',
      'search_profiles',
      'get_leaderboard',
      'get_my_leaderboard_rank',
      'start_async_duel',
    ]) {
      expect(
        sql,
        contains('FUNCTION public.$fn('),
        reason: '$fn göçte yeniden kurulmalı',
      );
    }
    final chunks = sql.split('CREATE OR REPLACE FUNCTION public.').skip(1);
    expect(chunks, hasLength(7));
    for (final chunk in chunks) {
      final name = chunk.substring(0, chunk.indexOf('('));
      final body = chunk.substring(0, chunk.indexOf(r'$function$;'));
      expect(body, contains('blocked_users'), reason: '$name engel süzmüyor');
    }
    // Oda: engelli olduğu ifşa edilmez, mevcut notFound eşlemesine düşer.
    expect(
      sql,
      contains("raise exception 'Room not found or already started'"),
    );
    // Arkadaşlık: boolean success=false; istemci mevcut başarısızlık metnini
    // gösterir.
    expect(sql, contains("'Friend request blocked'"));
  });

  test('L1/L2: görünüm açığı kapanır, anon yazamaz, istemci yolları korunur', () {
    final sql = _sql('2026-10-02_grants_hardening.sql');
    // Kusur: sahibi BYPASSRLS olan, güncellenebilir, security_invoker olmayan
    // görünüme anon INSERT/UPDATE/DELETE verilmişti → RLS atlanarak soru
    // bankasına yazılabiliyordu.
    expect(
      sql,
      contains(
        'alter view public.quiz_eligible_questions set (security_invoker = true)',
      ),
    );
    expect(sql, contains('revoke truncate, references, trigger on table'));
    expect(
      sql,
      contains('revoke insert, update, delete on table public.%I from anon'),
    );
    expect(
      sql,
      contains(
        "revoke all on function public.get_today_contest() from public, anon",
      ),
    );
    expect(sql, contains('rls_auto_enable() from public, anon, authenticated'));
    expect(sql, contains('enforce_display_name_policy() from public, anon'));
    expect(sql, contains('enqueue_friend_request_push() from public, anon'));
    // İstemcinin doğrudan yazdığı tablolar izin listesinde (kod taraması).
    for (final table in [
      'profiles',
      'favorite_questions',
      'question_reports',
      'room_messages',
      'suggested_questions',
      'user_lesson_progress',
    ]) {
      expect(sql, contains("when '$table' then"), reason: '$table kalmalı');
    }
  });

  test('L1/L2: lib/ yeni bir doğrudan tablo yazımı eklemedi', () {
    // Göç, istemcinin doğrudan yazdığı tabloları sabit listeyle korur. lib/ya
    // listede olmayan bir tabloya `.from(t).insert/update/delete/upsert`
    // eklenirse bu test kırılır — önce göçteki izin listesi güncellenmeli.
    const allowed = {
      'profiles',
      'favorite_questions',
      'question_reports',
      'room_messages',
      'suggested_questions',
      'user_lesson_progress',
      'blocked_users',
    };
    final writeCall = RegExp(
      r"\.from\(\s*'([a-z_0-9]+)'\s*\)\s*\.\s*(insert|update|delete|upsert)\(",
    );
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      for (final m in writeCall.allMatches(file.readAsStringSync())) {
        if (!allowed.contains(m.group(1))) {
          offenders.add('${file.path}: ${m.group(1)}.${m.group(2)}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('L3: rapor gerekçesi sınırlı, bildiren oda üyesi olmalı', () {
    final sql = _sql('2026-10-02_report_hardening.sql');
    for (final table in [
      'message_reports',
      'question_reports',
      'profile_reports',
    ]) {
      expect(sql, contains('${table}_reason_len'));
      expect(sql, contains('${table}_truncate_reason'));
    }
    expect(sql, contains('char_length(reason) <= 500'));
    expect(sql, contains('left(new.reason, 500)'));
    expect(sql, contains('rp.player_id = v_uid'));
    expect(sql, contains("raise exception 'Message not found'"));
    expect(sql, contains('drop policy if exists message_reports_insert_own'));
    // İstemci serbest metni göçten önce de kırpar.
    final repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(repo, contains('_clampReportReason'));
    expect(repo, contains('substring(0, 500)'));
  });

  test('Apple jeton tablosu istemciye kapalı, fonksiyon sırları kodda yok', () {
    final sql = _sql('2026-10-02_apple_auth_tokens.sql');
    expect(sql, contains('enable row level security'));
    expect(
      sql,
      contains(
        'revoke all on table public.apple_auth_tokens from public, anon, authenticated',
      ),
    );
    final fn = File(
      'supabase/functions/apple-revoke/index.ts',
    ).readAsStringSync();
    for (final secret in [
      'APPLE_TEAM_ID',
      'APPLE_KEY_ID',
      'APPLE_PRIVATE_KEY',
      'APPLE_CLIENT_ID',
    ]) {
      expect(fn, contains('Deno.env.get'));
      expect(fn, contains('requiredEnv("$secret")'));
    }
    expect(fn, contains('https://appleid.apple.com/auth/token'));
    expect(fn, contains('https://appleid.apple.com/auth/revoke'));
    expect(fn, isNot(contains('BEGIN PRIVATE KEY')));
    expect(fn, isNot(contains('BEGIN EC PRIVATE KEY')));
    // Kullanıcı kimliği JWT'den; gövdeden alınmaz.
    expect(fn, contains('admin.auth.getUser(jwt)'));
    expect(fn, isNot(contains('body.user_id')));
  });

  test('gizlilik: FCM jetonu hesaba bağlı DeviceID olarak beyan edilir', () {
    final manifest = File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
    final start = manifest.indexOf('NSPrivacyCollectedDataTypeDeviceID');
    expect(start, greaterThan(0));
    final end = manifest.indexOf('</dict>', start);
    final block = manifest.substring(start, end);
    expect(
      block,
      contains('NSPrivacyCollectedDataTypeLinked</key>\n\t\t\t<true/>'),
    );
    expect(
      block,
      contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
    );
    // Firebase Analytics kurulum kimliği beyanı düşürülmedi.
    expect(block, contains('NSPrivacyCollectedDataTypePurposeAnalytics'));
    expect(
      block,
      contains('NSPrivacyCollectedDataTypeTracking</key>\n\t\t\t<false/>'),
    );
  });

  test(
    'gizlilik sayfası: jeton, Apple/Google e-postası, saklama, iletişim',
    () {
      final html = File('web/privacy.html').readAsStringSync();
      final terms = File('web/terms.html').readAsStringSync();
      expect(html, contains('Bildirim jetonu'));
      expect(html, contains('Nîşana agahdariyan'));
      expect(html, contains('Apple veya Google ile giriş yaparsan'));
      expect(html, contains('heke bi Apple an Google têkevî'));
      expect(html, contains('Verilerin ne kadar süre saklanıyor?'));
      expect(html, contains('Daneyên te çiqas dem tên parastin?'));
      // İletişim adresi şartlar sayfasındakiyle aynı.
      final mail = RegExp(r'mailto:([^"?]+)').firstMatch(terms)!.group(1)!;
      expect('mailto:$mail'.allMatches(html).length, greaterThanOrEqualTo(2));
    },
  );
}
