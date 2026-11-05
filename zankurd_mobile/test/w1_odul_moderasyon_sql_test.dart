/// `2026-11-16_w1_odul_moderasyon.sql` bekçisi (2.1.2 W1): GPT-6 Pro denetiminin
/// ödül / moderasyon / bildirim-claim SQL bulguları.
///
/// ## Kusurlar
///
/// * `claim_verified_solo_reward` tek soruluk, sıfır doğru ya da anında biten
///   turdan 4 jeton verirdi; davet ödülü bu `solo_round` kaydını "oynadı"
///   kanıtı sayardı.
/// * `claim_share_reward` hiç oynamamış hesaba doğrudan RPC ile günde 25 jeton.
/// * Kısıtlı (engelli/askıdaki) hesap solo/paylaşım/davet ödülü alır, haftalık
///   lige girer, turnuvaya yazılırdı.
/// * `admin_reward_contributor` aynı isteğin yeniden gönderiminde ikinci kez öder.
/// * `spend_coins_once` aynı anahtarı başka tutarla "başarı" sayardı; `record_activity`
///   sayacı sınırsız şişerdi; `push_delivery_v2_allowed` iptal edilmiş arkadaşlık
///   isteğinin ve kapatılmış yönetici bildiriminin gönderimine izin verirdi.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: ödüller "başarıyla" verilir, yalnız ekonomi/sıralama
/// sapar. Davranış `tool/test_w1_odul_moderasyon_local.mjs` ile PGlite'ta
/// kanıtlanır (her kusur göçten ÖNCE gösterilir); bu dosya metni ve istemci
/// uyumunu sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File(
    'supabase/2026-11-16_w1_odul_moderasyon.sql',
  ).readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-16_w1_odul_moderasyon_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) =>
      s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
  final code = strip(raw);
  final geri = strip(geriRaw);

  test('tek işlem, küçük harfli begin/commit; geri alma da; applied ✅', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-16_w1_odul_moderasyon.sql | ✅'));
    expect(code, isNot(contains('lock table')));
  });

  test('tam gövde md5 ön koşulu, yedek + yama zinciri, son güvenlik', () {
    expect(
      RegExp(r"'[0-9a-f]{32}', '[0-9a-f]{32}'").allMatches(code).length,
      11,
    );
    expect(code, isNot(contains('TABAN_')));
    expect(code, isNot(contains('NIHAI_')));
    expect(code, contains('v_eski_n <> 1'));
    expect(code, contains("'w1:' || p_imza"));
    expect(code, contains('bu sürümün nihai gövdesi'));
    expect(code, contains('p.prosecdef'));
    expect(code, contains('p.proowner = r.sahip'));
    expect(code, contains('p.proacl::text is not distinct from r.acl'));
    expect(code, contains("has_function_privilege('anon'"));
    expect(geri, contains('for update;'));
    expect(geri, contains('yedek satırı yok; hiçbir işlev geri alınmadı'));
    expect(geri, contains('canlı gövdesi göçten sonra değişmiş'));
    expect(geri, contains('execute r.eski'));
    expect(geri, isNot(contains('ad like')));
    // Taban md5'leri applied.md'de de yazılı (canlıda doğrulanacak liste).
    for (final m in RegExp(
      r"'public\.[a-z_0-9]+\([^)]*\)', '([0-9a-f]{32})', '[0-9a-f]{32}'",
    ).allMatches(code)) {
      expect(applied, contains(m.group(1)!), reason: 'applied.md md5 listesi');
    }
  });

  test('#2/#11: solo ödülünde taban yok; asgari soru/doğru/süre', () {
    expect(
      code,
      contains('v_n < 4 or v_session.correct_count < 1 or v_secs < v_n * 0.5'),
    );
    expect(code, contains("'not_eligible', true"));
    expect(code, contains('user_is_restricted(auth.uid())'));
  });

  test('#1: paylaşım ödülü doğrulanmış etkinliğe bağlı', () {
    expect(code, contains('public.verified_quiz_sessions s'));
    expect(code, contains('cardinality(s.question_ids) >= 4'));
    expect(code, contains("'No verified play today'"));
    expect(code, contains('public.async_duel_results r'));
  });

  test('#5: kısıtlı hesap yolları (davet iki yön, lig, turnuva)', () {
    expect(code, contains('user_is_restricted(v_user_id)'));
    expect(code, contains('user_is_restricted(v_ref_id)'));
    expect(code, contains('not public.user_is_restricted(v_uid)'));
    expect(code, contains('not public.user_is_restricted(r.player_id)'));
    expect(code, contains('before insert on public.tournament_entries'));
    expect(
      code,
      contains("raise exception 'account_restricted' using errcode = '42501'"),
    );
  });

  test(
    '#6: katkı ödülü request_id + benzersiz indeks; geri alma yeni nesneleri siler',
    () {
      expect(code, contains('add column if not exists request_id uuid'));
      expect(
        code,
        contains(
          'create unique index if not exists admin_contributor_rewards_request_uidx',
        ),
      );
      expect(code, contains("'request_id_conflict'"));
      expect(
        geri,
        contains(
          'drop function if exists public.admin_reward_contributor(uuid, integer, text, uuid)',
        ),
      );
      expect(
        geri,
        contains('drop trigger if exists trg_w1_tournament_entries_restricted'),
      );
    },
  );

  test('istemci: katkı ödülü isteği request_id taşır ve eski imzaya düşer', () {
    final repo = File(
      'lib/src/data/supabase_admin_repository.dart',
    ).readAsStringSync();
    expect(repo, contains("'p_request_id': requestId"));
    expect(repo, contains("error.code != 'PGRST202' && error.code != '42883'"));
    expect(repo, contains('_pendingRewardRequests.remove(key)'));
  });

  test(
    'eski istemci sözleşmesi: yeni göç hiçbir mevcut imzayı düşürmez/değiştirmez',
    () {
      // Yalnız `create or replace function` yeni (aşırı yüklenmiş) imzalar için var;
      // mevcut RPC'ler yamayla değişir. `drop function` yalnız geri alma dosyasında.
      expect(code, isNot(contains('drop function')));
      expect(code, isNot(contains('alter function')));
      expect(
        RegExp(
          r'create or replace function public\.([a-z_0-9]+)',
        ).allMatches(code).map((m) => m.group(1)).toSet(),
        {'admin_reward_contributor', 'w1_guard_tournament_entry'},
      );
    },
  );
}
