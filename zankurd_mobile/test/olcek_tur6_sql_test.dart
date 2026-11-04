/// `2026-11-05_olcek_tur6.sql` bekçisi: GPT-6 Pro tam denetiminin sunucu
/// bulguları.
///
/// ## Kusurlar
///
/// * `create_online_room_impl` bakiye kontrolünü "mevcut canlı odayı dön"
///   dalından ÖNCE yapıyordu: ücretli oda kurulunca bakiye düşer, aynı
///   çağrının ağ tekrarı "Insufficient coins" alırdı.
/// * `reconcile_player_score_daily` yalnız son 2 günü ve en çok 2000 çifti
///   ele alıyordu; eski ya da sığmayan sapma kalıcı olarak kaçabilirdi.
/// * `reconcile_player_score_total` dilimi LIMIT'i oyuncuyu tekilleştirmeden
///   önce uyguluyordu; bazı oyunculara hiç ulaşılmıyordu.
/// * `get_tournament_bracket` her okumada bütün (bitmiş dahil) turnuvaları
///   `for update` ile kilitleyip tarıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: yanlış ret yalnız tekrar denemede, kaçan sapma yalnız
/// eski günlerde, kilit yalnız yük altında görünür. Davranış
/// `tool/test_olcek_tur6_local.mjs` ile PGlite'ta kanıtlanır (taban kusuru
/// göçten ÖNCE gösterilir); bu dosya metni sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-05_olcek_tur6.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-05_olcek_tur6_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
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
    expect(applied, contains('2026-11-05_olcek_tur6.sql | ✅'));
    expect(code, isNot(contains('lock table')));
  });

  test('tam gövde md5 ön koşulu, yedek + yama zinciri, son güvenlik', () {
    expect(
      RegExp(r"'[0-9a-f]{32}', '[0-9a-f]{32}'").allMatches(code).length,
      4,
    );
    expect(code, isNot(contains('TABAN_')));
    expect(code, isNot(contains('NIHAI_')));
    expect(code, contains('v_eski_n <> 1'));
    expect(code, contains("'tur6:' || p_imza"));
    expect(code, contains('bu sürümün nihai gövdesi'));
    expect(code, contains('p.prosecdef'));
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

  test('A: bakiye kontrolü mevcut-oda dalından sonra, hız sınırından önce', () {
    final mevcut = raw.indexOf("-- Aktif oda varsa snapshot'ı dön (2026-11-05");
    final bakiye = raw.indexOf("raise exception 'Insufficient coins", mevcut);
    final hiz = raw.indexOf('Saatte en çok 30 yeni oda', bakiye);
    expect(mevcut, greaterThan(0));
    expect(bakiye, greaterThan(mevcut));
    expect(hiz, greaterThan(bakiye));
  });

  test('B: kalıcı imleç, sıralı kilit, elle tam geri doldurma, ayrı cron', () {
    expect(code, contains('score_reconcile_daily_cursor'));
    expect(code, contains('reconcile_player_score_daily_full'));
    expect(code, contains('order by t.p, t.d'));
    expect(code, contains('for update skip locked'));
    expect(
      code,
      contains("'reconcile-player-score-daily-sweep', '35 0 * * *'"),
    );
    expect(code, contains('to service_role'));
    expect(
      code,
      isNot(contains("'public.reconcile_player_score_daily(integer)'")),
      reason: 'mevcut 00:15 işlevi yamalanmaz',
    );
  });

  test('C: önce tekilleştir sonra LIMIT', () {
    expect(code, contains('select distinct d.player_id'));
  });

  test('D: bracket okuması yan etkisiz, süre dolumu cron\'da', () {
    expect(code, contains("'tournament-expiry', '* * * * *'"));
    expect(code, contains('process_tournament_expiry'));
    expect(code, contains("where t.status = 'running'"));
    expect(code, contains('tournament_matches_open_deadline_idx'));
    final bracket = code.substring(
      code.indexOf("'public.get_tournament_bracket()',\n  \$e\$"),
    );
    expect(bracket, contains('KİLİTSİZ'));
  });
}
