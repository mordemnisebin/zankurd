/// `2026-11-05_olcek_tur5.sql` bekçisi: dördüncü ölçek denetiminin sunucu
/// bulguları.
///
/// ## Kusurlar
///
/// * `join_matchmaking` ikinci geçişte `matchmaking:<kategori>` kilidini
///   TUTARKEN `pg_sleep(0.03)` (en çok 5 kez) uyuyordu; yük altında bir
///   kategorinin bütün arayanları bu uykuyla seri bekliyordu.
/// * `get_my_league`, cron geciktiğinde her çağrıda geçen haftayı kapatmaya
///   kalkıyordu; haftanın ilk dakikalarında herkes aynı kilitte yığılıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Sonuçlar doğruydu; yalnız yük altında yavaşlar. Eşleşme doğruluğu (iki kişi
/// tam bir kez eşleşir, üçüncü bekler), yama idempotansı ve geri alma
/// `tool/test_olcek_tur5_local.mjs` ile PGlite'ta doğrulanır; bu dosya metni
/// sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-05_olcek_tur5.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-05_olcek_tur5_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) =>
      s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
  final code = strip(raw);
  final geri = strip(geriRaw);

  test(
    'tek işlem, küçük harfli begin/commit; geri alma da; applied ✅ (canlı)',
    () {
      expect(code.trimLeft(), startsWith('begin;'));
      expect(code.trimRight(), endsWith('commit;'));
      expect(geri.trimLeft(), startsWith('begin;'));
      expect(geri.trimRight(), endsWith('commit;'));
      expect(raw, isNot(contains('COMMIT')));
      expect(geriRaw, isNot(contains('COMMIT')));
      expect(applied, contains('2026-11-05_olcek_tur5.sql | ✅'));
      expect(code, isNot(contains('lock table')));
    },
  );

  test('yama muhafızı: tam bir kez, yedek + md5, geri alma md5 doğrular', () {
    expect(code, contains('v_eski_n <> 1'));
    expect(code, contains('v_yeni_n <> 0'));
    expect(code, contains("'tur5:' || p_imza"));
    expect(code, contains('md5(v_def)'));
    expect(geri, contains('yama-md5'));
    expect(geri, contains('canlı gövdesi göçten sonra değişmiş'));
  });

  test('join_matchmaking: kilit altında uyku yok, kilit uykudan sonra', () {
    final blok = code.substring(
      code.indexOf('v_opponent is null and not v_locked'),
    );
    final uyku = blok.indexOf('perform pg_sleep(0.03)');
    final kilit = blok.indexOf(
      "pg_try_advisory_xact_lock(hashtextextended('matchmaking:'",
    );
    expect(uyku, greaterThan(0));
    expect(kilit, greaterThan(uyku), reason: 'uyku yalnız kilitsiz geçişte');
    expect(blok.indexOf('v_locked := true'), greaterThan(kilit));
    expect('pg_sleep'.allMatches(blok).length, 1);
    expect(blok, contains("return json_build_object('status', 'waiting')"));
  });

  test(
    'göç: taban md5, yedek zinciri, son güvenlik doğrulaması; geri: hep ya hiç',
    () {
      expect(code, contains('tur5_durum'));
      expect(code, contains('p.prosecdef'));
      expect(code, contains('aclexplode'));
      expect(code, contains('p.proowner = r.sahip'));
      expect(code, contains('bu sürümün nihai gövdesi'));
      expect(geri, contains('for update;'));
      expect(geri, contains('execute v_eskiler[v_i]'));
      expect(code, contains("has_function_privilege('anon'"));
      expect(code, contains('revoke all on public.olcek_tur3_yedek'));
      expect(code, contains("'league-rollover:' || v_week::text"));
      expect(geri, isNot(contains('ad like')));
      expect(geri, contains('yedek satırı yok; hiçbir işlev geri alınmadı'));
      expect(geri, contains('yok; geri alma durdu'));
      expect(
        geri,
        contains('grant execute on function public.get_my_league()'),
      );
    },
  );

  test('get_my_league: tek uçuş, rollover ile aynı anahtar', () {
    expect(code, contains('pg_try_advisory_xact_lock('));
    expect(code, contains("'league-rollover:' || (v_week - 7)::text"));
    expect(code, contains('not v_pending'));
    final lig = File('supabase/2026-11-05_haftalik_lig.sql').readAsStringSync();
    expect(lig, contains("'league-rollover:' || v_week::text"));
  });
}
