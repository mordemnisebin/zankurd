/// `2026-11-06_guvenlik_tur7.sql` bekçisi: GPT-6 Pro alan 2 + alan 3
/// denetimlerinin SQL bulguları.
///
/// ## Kusurlar
///
/// * `get_async_duel_review`: düello oluştur -> `cancel_my_async_duel`
///   ('expired') -> inceleme zinciri tek soru oynamadan 7 doğru şıkkı açıyordu.
/// * `assign_player_tag` + `redeem_referral_code`: istemci INSERT'inde dolu
///   etiket kabul ediliyor, ham metin UNIQUE'i `4F7K` ile `ZK-4F7K`yi ayrı
///   sayıyordu; paylaşılan `ZK-4F7K` taklit profile gidip jetonu yanlış kişiye
///   veriyordu. Ömür boyu 10 ödül sınırı davet edilenin silinmesiyle düşüyordu;
///   çağıran -> davet eden kilidi A<->B karşılıklı kullanımda döngü yapıyordu.
/// * `fcm_token`: profil INSERT/UPDATE korumaları kapsamıyordu; kilitsiz
///   "temizle-sonra-yaz" aynı token'ı iki hesapta bırakabiliyordu.
/// * `report_question`: UUID harf büyüklüğü varyantları ayrı rapor sayılıp tek
///   hesap `report_count`'u 5'e çıkarabiliyordu.
/// * `limit_suggested_question_rate`: kota istemcinin verdiği `created_at`'i
///   sayıyordu (NULL/eski tarih kaçıyordu).
/// * `add_friend`: günlük 30 ve hedef başına saatlik sınır silinebilir
///   `friend_requests` geçmişinden hesaplanıyordu (gönder -> remove_friend ->
///   yeniden gönder).
/// * Kilit sırası: `claim_quiz_reward` (profil -> oda) ile
///   `acknowledge_room_result` (oda -> profil), `recompute_player_score_day`
///   (gün -> toplam), `room_heartbeat` (room_players -> rooms) ters sıralıydı.
/// * `expire_async_duels`: sınırsız tek sorgu + kilit beklemesi; hükmen XP'nin
///   yeniden denemesi 7 günlük pencereye bağlıydı.
/// * `log_analytics_event` kullanıcı kilidi taşımıyor (600/saat aşılabilir);
///   `get_my_records` rekoru eski tablodan okuyor; `mark_room_client_ready`
///   ücretli iki kişilik odada iade etmiyor; `join_tournament` kilitsiz.
/// * Bekleyen `solo_daily_verified.sql`: şık doğrulaması ve indeks yoktu; iki
///   geri alma dosyası ortak yedek tablosunu/bağımlı işlevleri bozuyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: sızıntı yalnız bilerek kurulan zincirde, kotalar yalnız
/// saldırıda, kilit sıraları yalnız eşzamanlı yük altında, geri doldurma yalnız
/// eski veride görünür. Davranış `tool/test_guvenlik_tur7_local.mjs` ile
/// PGlite'ta kanıtlanır (her kusur göçten ÖNCE gösterilir); bu dosya metni
/// sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-06_guvenlik_tur7.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-06_guvenlik_tur7_geri.sql',
  ).readAsStringSync();
  final indeks = File(
    'supabase/2026-11-06_guvenlik_tur7_indeks_concurrently.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  final bekleyen = File(
    'supabase/2026-11-01_solo_daily_verified.sql',
  ).readAsStringSync();
  final tur3Geri = File(
    'supabase/geri_al/2026-11-05_olcek_tur3_geri.sql',
  ).readAsStringSync();
  final turnuvaGeri = File(
    'supabase/geri_al/2026-10-27_turnuva_sunucu_puani_geri.sql',
  ).readAsStringSync();
  String strip(String s) =>
      s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
  final code = strip(raw);
  final geri = strip(geriRaw);

  test('tek işlem, küçük harfli begin/commit; geri alma da; applied ⏳', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-06_guvenlik_tur7.sql | ⏳'));
    expect(
      applied,
      contains('2026-11-06_guvenlik_tur7_indeks_concurrently.sql | ⏳'),
    );
    expect(code, isNot(contains('lock table')));
    // Göç yeni nesne yaratmaz: tablo/işlev/cron/indeks yok.
    expect(code, isNot(contains('create table if not exists')));
    expect(code, isNot(contains('cron.schedule')));
    expect(code, isNot(contains('create index')));
  });

  test('tam gövde md5 ön koşulu, yedek + yama zinciri, son güvenlik', () {
    expect(
      RegExp(r"'[0-9a-f]{32}', '[0-9a-f]{32}'").allMatches(code).length,
      18,
    );
    expect(code, isNot(contains('TABAN_')));
    expect(code, isNot(contains('NIHAI_')));
    expect(code, contains('v_eski_n <> 1'));
    expect(code, contains("'tur7:' || p_imza"));
    expect(code, contains('bu sürümün nihai gövdesi'));
    expect(code, contains('p.prosecdef = r.secdef'));
    expect(code, contains('p.proowner = r.sahip'));
    expect(code, contains('p.proacl::text is not distinct from r.acl'));
    expect(code, contains("has_function_privilege('anon'"));
    expect(code, contains('aclexplode'));
    expect(geri, contains('for update;'));
    expect(geri, contains('yedek satırı yok; hiçbir işlev geri alınmadı'));
    expect(geri, contains('canlı gövdesi göçten sonra değişmiş'));
    expect(geri, contains('execute r.eski'));
    expect(geri, isNot(contains('ad like')));
  });

  test('18 işlev yamalanır, istemci sözleşmesi (imza) korunur', () {
    for (final imza in const [
      'get_async_duel_review(uuid)',
      'assign_player_tag()',
      'redeem_referral_code(text)',
      'profiles_client_insert_authority()',
      'profiles_client_write_guard()',
      'set_fcm_token(text)',
      'report_question(text)',
      'question_reports_before_insert()',
      'limit_suggested_question_rate()',
      'add_friend(uuid,text)',
      'recompute_player_score_day(uuid,date)',
      'expire_async_duels()',
      'log_analytics_event(text,jsonb)',
      'get_my_records()',
      'mark_room_client_ready(uuid)',
      'room_heartbeat(uuid)',
      'join_tournament()',
      'claim_quiz_reward(uuid,integer,integer,integer,integer)',
    ]) {
      expect(code, contains("'public.$imza'"), reason: imza);
      expect(geri, contains("'public.$imza'"), reason: imza);
    }
    expect(code, isNot(contains('drop function')));
    expect(code, isNot(contains('create or replace function public.')));
  });

  test('düzeltmelerin bağlayıcı parçaları', () {
    expect(code, contains('where mine.duel_id is not null;'));
    expect(code, contains("current_setting('role', true)"));
    expect(code, contains("regexp_replace(upper(btrim(p_code)), '^ZK-', '')"));
    expect(code, contains("ct.reason = 'referral_invite'"));
    expect(code, contains('order by id\n  for update;'));
    expect(code, contains('new.fcm_token := null;'));
    expect(code, contains('new.fcm_token := old.fcm_token;'));
    expect(code, contains("hashtextextended('fcm:' || v_token, 0)"));
    expect(code, contains('lower(question_id) = lower(p_question_id)'));
    expect(code, contains('new.created_at := now();'));
    expect(code, contains("'add_friend_to:' || p_friend_id::text, 1"));
    expect(code, contains("'add_friend_day', 30"));
    expect(code, contains("hashtextextended('score-total:'"));
    expect(code, contains('limit 500\n    for update of d skip locked'));
    expect(code, contains('r.xp_awarded = false'));
    expect(
      code,
      contains("hashtextextended('analytics:' || v_user_id::text, 0)"),
    );
    expect(code, contains('public.daily_event_results der'));
    expect(code, contains('refund_room_entry_fees(p_room_id, null, true)'));
    expect(code, contains("hashtextextended('tournament-join:'"));
    expect(code, contains("hashtextextended('tournament-alloc', 0)"));
  });

  test('kilit sırası: ödül önce oda sonra profil; heartbeat önce oda', () {
    final odaKilidi = raw.indexOf('Kilit sırası oda -> profil');
    final profilKilidi = raw.indexOf(
      'perform 1 from public.profiles where id = v_player_id for update;',
      odaKilidi,
    );
    expect(odaKilidi, greaterThan(0));
    expect(profilKilidi, greaterThan(odaKilidi));
    final hb = raw.indexOf(
      'perform 1 from public.rooms r where r.id = p_room_id for update;',
    );
    final hbYazim = raw.indexOf("En çok 10 sn'de bir yazım", hb);
    expect(hb, greaterThan(0));
    expect(hbYazim, greaterThan(hb));
  });

  test('indeksler transaction dışı, concurrently', () {
    expect(indeks, isNot(contains('begin;')));
    expect(indeks, isNot(contains('commit;')));
    expect(
      RegExp('create index concurrently if not exists').allMatches(indeks),
      hasLength(3),
    );
    expect(indeks, contains('async_duel_answers (player_id, answered_at)'));
    expect(
      indeks,
      contains('tournament_match_answers (player_id, answered_at)'),
    );
    expect(indeks, contains("where status in ('open', 'matched')"));
  });

  test('bekleyen solo_daily_verified: şık doğrulaması, indeks, sabit eşik', () {
    expect(bekleyen, contains("check (choice in ('', 'A', 'B', 'C', 'D'))"));
    expect(bekleyen, contains("raise exception 'Invalid choice'"));
    expect(bekleyen, contains('verified_solo_selections_user_created_idx'));
    expect(bekleyen, contains('v_since timestamptz := clock_timestamp()'));
    expect(bekleyen, contains('created_at > v_since'));
    expect(bekleyen, contains('verified_daily_event_results vr'));
  });

  test('geri alma dosyaları: ortak yedek tablosu ve bağımlı işlevler', () {
    // 23: tur3 geri alması sonraki göçlerin yedek satırı varken durur ve
    // tabloyu koşulsuz düşürmez.
    expect(tur3Geri, contains("ad ~ '^tur[0-9]+:'"));
    expect(tur3Geri, contains('önce onları ters sırayla geri al'));
    expect(
      tur3Geri,
      isNot(contains('\ndrop table if exists public.olcek_tur3_yedek;')),
    );
    // 22: turnuva geri alması bağımlı işlev varken durur.
    expect(turnuvaGeri, contains('turnuva_bagimlilik'));
    expect(
      turnuvaGeri,
      contains('tournament_match_(answers|questions|question_starts)'),
    );
  });
}
