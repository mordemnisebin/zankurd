/// `2026-11-05_olcek_tur4.sql` bekçisi: üçüncü ölçek denetiminin (Copilot +
/// Gemini Flash) sunucu bulguları ve istemci yoklama bütçesi.
///
/// ## Kusurlar
///
/// * Tüm zamanlar sıralaması (`get_leaderboard(-1)`, `get_my_leaderboard_rank(-1)`,
///   `get_friends_leaderboard(-1)`) bütün `player_score_daily` (oyuncu x gün)
///   tablosunu her çağrıda gruplıyordu; tablo oyuncu sayısıyla DEĞİL oyuncu x
///   gün sayısıyla büyür. Şimdi oyuncu başına tek satırlık `player_score_total`
///   okunur; bakımı günlük satırı yazan işlemde yapılır.
/// * `weekly_league_assign` kademe başına BEKLEYEN advisory kilit alıyordu:
///   pazartesi ilk puanı alan herkes tek sıraya giriyordu.
/// * İstemci: eşleşme yoklaması 3 sn, düello hazır vuruşu 400 ms, oda daveti
///   ve arkadaşlar yoklaması 20 sn'de bir sunucuya gidiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Sonuçlar doğruydu; yalnız yük altında yavaşlar. Davranış denkliği (göç
/// öncesi/sonrası birebir aynı sıralama, toplamın bakımı, 30 sınırı, geri
/// alma) `tool/test_olcek_tur4_local.mjs` ile PGlite'ta doğrulanır; bu dosya
/// metni ve bütçeyi sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/poll_cadence.dart';

void main() {
  final raw = File('supabase/2026-11-05_olcek_tur4.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-05_olcek_tur4_geri.sql',
  ).readAsStringSync();
  final tur3Raw = File('supabase/2026-11-05_olcek_tur3.sql').readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();

  String strip(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
  final code = strip(raw);
  final geri = strip(geriRaw);

  test('tek işlem, küçük harfli begin/commit; geri alma da; ⏳', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-05_olcek_tur4.sql | ⏳'));
    expect(code, isNot(contains('lock table')));
    expect(code, isNot(contains('create index concurrently')));
  });

  test('tur3 başlığı artık canlıda diyor (bayat "UYGULANMADI" yok)', () {
    final ilk = tur3Raw.split('\n').take(3).join('\n');
    expect(ilk, isNot(contains('CANLIYA UYGULANMADI')));
    expect(ilk, contains('Canlıda (2026-11-05)'));
  });

  test('yamalar: bağlayıcı TAM BİR kez, eski gövde yedeklenir', () {
    expect(code, contains('pg_get_functiondef'));
    expect(code, contains("raise exception 'tur4: % için bağlayıcı durumu"));
    expect(code, contains('v_eski_n <> 1'));
    expect(code, contains('v_yeni_n <> 0'));
    expect(code, contains('on conflict (ad) do update'));
    expect(code, isNot(contains('on conflict (ad) do nothing')));
    expect(geri, contains('yama-md5'));
    expect(code, contains('md5(v_def)'));
    expect(code, contains("'tur4:' || p_imza"));
    for (final imza in [
      'recompute_player_score_day(uuid,date)',
      'rebuild_player_score_daily(date)',
      'reconcile_player_score_daily(integer)',
      'leaderboard_daily_rows(integer,uuid[])',
      'weekly_league_assign(uuid,date)',
    ]) {
      expect(code, contains("'public.$imza'"), reason: imza);
      expect(geriRaw, isNot(contains('tur4_yama')));
    }
  });

  test(
    'tüm zamanlar: toplam tablosu okunur, günlük tablo yalnız pencerede',
    () {
      expect(
        code,
        contains('create table if not exists public.player_score_total'),
      );
      expect(code, contains('player_id uuid primary key'));
      expect(code, contains('where p_days <= 0'));
      expect(code, contains('where e.ts is not null and a.day > e.d'));
      // Sıralama işlevlerinin gövdesi bu göçte DEĞİŞMEZ (aynı sonuç garantisi).
      for (final ad in [
        'get_leaderboard',
        'get_my_leaderboard_rank',
        'get_friends_leaderboard',
      ]) {
        expect(code, isNot(contains('function public.$ad(')), reason: ad);
      }
    },
  );

  test('toplamın bakımı: aynı işlemde, oyuncu başına kilit, fark değil '
      'yeniden hesap, mutabakat ve onarım bağlı', () {
    final i = code.indexOf('function public.refresh_player_score_total(');
    final b = code.substring(i, code.indexOf(r'$function$;', i + 80));
    expect(b, contains("'score-total:'"));
    expect(b, contains('pg_advisory_xact_lock'));
    expect(b, contains('max(d.streak)'));
    expect(
      code,
      contains('perform public.refresh_player_score_total(p_player_id);'),
    );
    expect(code, contains('perform public.rebuild_player_score_total_all();'));
    expect(
      code,
      contains('perform public.reconcile_player_score_total(p_days, 1000);'),
    );
    // Mutabakat hata yutar: günlük mutabakatı bozmaz.
    expect(code, contains('exception when others then'));
    // Geri doldurma: kapsama + oyuncu kilidiyle artan sırada yeniden hesap;
    // mutabakat dönen imleçle eski sapmayı da yakalar.
    expect(
      code,
      contains('select public.rebuild_player_score_total(null, 3000);'),
    );
    expect(code, contains('score_total_reconcile_cursor'));
    expect(
      code,
      contains('order by x.player_id\n    limit greatest(p_limit, 1)'),
    );
  });

  test(
    'lig ataması: satır kilidi skip locked, oluşturma kilidi dar, 30 sınırı',
    () {
      final i = code.indexOf("'public.weekly_league_assign(uuid,date)'");
      final b = code.substring(i, code.indexOf('commit;', i));
      expect(b, contains('for update skip locked'));
      expect(b, contains("'league-cohort-create:'"));
      expect(b, contains("'league-player:'"));
      expect(b, contains('member_count < 30'));
    },
  );

  test('geri alma: yedekten, okuyan işlev tabloyu bırakmadan önce döner', () {
    expect(geri, contains("like 'tur4:%'"));
    final doIdx = geri.indexOf('do \$tur4_geri\$');
    expect(doIdx, greaterThanOrEqualTo(0));
    expect(
      geri.indexOf('drop table if exists public.player_score_total'),
      greaterThan(doIdx),
    );
  });

  test('istemci yoklama bütçesi: dakikada istek sayısı', () {
    expect(
      PollCadence.perMinute(PollCadence.matchmakingTouch),
      10,
    ); // eskiden 20
    expect(
      PollCadence.perMinute(PollCadence.readyPing),
      lessThanOrEqualTo(40),
    ); // eskiden 150
    expect(PollCadence.perMinute(PollCadence.socialRefresh), 1); // eskiden 3
    // Sunucudaki 12 sn bayatlık kuralına iki vuruş sığar.
    expect(PollCadence.matchmakingTouch.inSeconds * 2, lessThanOrEqualTo(12));
  });

  test('ekranlar yeni sabitleri kullanır; ön plana dönüşte anında tazeler', () {
    String src(String p) => File('lib/src/screens/$p').readAsStringSync();
    expect(
      src('matchmaking_screen.dart'),
      contains('PollCadence.matchmakingTouch'),
    );
    expect(
      src('matchmaking_screen.dart'),
      contains('AppLifecycleState.resumed'),
    );
    expect(src('quiz_screen.dart'), contains('PollCadence.readyPing'));
    expect(src('quiz_screen.dart'), contains("'ack': true"));
    expect(src('friends_screen.dart'), contains('PollCadence.socialRefresh'));
    expect(
      src('home/room_invite_card.dart'),
      contains('PollCadence.socialRefresh'),
    );
    expect(
      src('matchmaking_screen.dart'),
      isNot(contains('Timer.periodic(const Duration(seconds: 3)')),
    );
    expect(
      src('quiz_screen.dart'),
      isNot(contains('Duration(milliseconds: 400), (_)')),
    );
  });
}
