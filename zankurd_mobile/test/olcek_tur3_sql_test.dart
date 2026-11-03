/// `2026-11-05_olcek_tur3.sql` bekçisi: ikinci ölçek denetimi (Copilot + Gemini
/// Flash) bulgularının sunucu tarafı.
///
/// ## Kusurlar
///
/// * `join_matchmaking` her çağrıda `matchmaking:<kategori>` kilidini
///   BEKLEYEREK alıyordu; "Rastgele" tek sanal kuyruk olduğundan bütün arayanlar
///   sıraya giriyordu. Şimdi kilit yalnız rakip bulunamayınca (ikinci geçiş)
///   alınır; istemci bekleme sırasında join'i yeniden çağırmadığından ikinci
///   geçiş kaldırılırsa "ikisi de görmeden bekler" yarışı iki oyuncuyu sonsuza
///   dek bekletir.
/// * Varlık yoklaması iki RPC'ydi (görünürlük + dokunuş).
/// * `cleanup_stale_rooms` her 5 dakikada bütün lobi/aktif odalar için
///   korelasyonlu max() alt sorguları çalıştırıyordu.
/// * `push_outbox` ve `rate_limit_events` hiç temizlenmiyordu.
/// * `get_my_leaderboard_rank` bütün oyuncular üstünde row_number() penceresi
///   sıralıyordu.
/// * `player_score_daily` tetikleyicisi hatayı WARNING ile yutuyor, sapmayı
///   kimse görmüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hepsi doğru sonuç veren SQL'dir; yalnız yük altında yavaşlar ya da tablo
/// büyür. Davranış denkliği (sıra eşitlik kırma, yamaların derlenmesi,
/// geri alma, mutabakat) `tool/test_olcek_tur3_local.mjs` ile PGlite'ta
/// doğrulanır; bu dosya metni sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-05_olcek_tur3.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-05_olcek_tur3_geri.sql',
  ).readAsStringSync();
  final indexRaw = File(
    'supabase/2026-11-05_olcek_tur3_indeks_concurrently.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  final repo = File(
    'lib/src/data/supabase_zankurd_repository.dart',
  ).readAsStringSync();

  String strip(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
  final code = strip(raw);
  final geri = strip(geriRaw);
  final index = strip(indexRaw);

  String body(String name) {
    final start = code.indexOf('function public.$name(');
    expect(start, greaterThanOrEqualTo(0), reason: '$name tanımı yok');
    final end = code.indexOf(
      r'$function$;',
      code.indexOf(r'$function$', start) + 1,
    );
    return code.substring(start, end);
  }

  test('tek işlem, küçük harfli begin/commit; geri alma da; uygulanmadı ⏳', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-05_olcek_tur3.sql | ⏳'));
  });

  test('tablo düzeyi kilit yok; büyük tablo indeksi göçte değil', () {
    expect(code, isNot(contains('lock table')));
    expect(code, isNot(contains('create index concurrently')));
    // Göçte yalnız küçük sıcak tablo indeksi (matchmaking_queue).
    final idx = RegExp(
      r'create index if not exists (\w+)\s+on public\.(\w+)',
    ).allMatches(code).map((m) => m.group(2)).toList();
    expect(idx, ['matchmaking_queue']);
    expect(index, isNot(contains('begin;')));
    expect(index, isNot(contains('commit;')));
    for (final ad in [
      'idx_rooms_open_created',
      'push_outbox_terminal_created_idx',
      'rate_limit_events_created_idx',
    ]) {
      expect(index, contains('create index concurrently if not exists $ad'));
    }
  });

  test('join_matchmaking: kilit yalnız ikinci geçişte, bayat silme '
      'skip locked, bağlayıcı TAM BİR kez', () {
    expect(code, contains('pg_get_functiondef'));
    expect(code, contains('tur3_yama2'));
    expect(code, contains('if v_opponent is null and v_pass = 1 then'));
    expect(code, contains('continue;'));
    // Kilit çağrısı iki kez geçer: eski satırın bağlayıcısı ($e$) ve yeni
    // yer; yeni olan yalnız ikinci geçişin (v_pass = 1) içindedir.
    final kilit = RegExp(
      r"perform pg_advisory_xact_lock\(hashtextextended\('matchmaking:'",
    ).allMatches(code).toList();
    expect(kilit.length, 2);
    expect(
      kilit.last.start,
      greaterThan(code.indexOf('if v_opponent is null and v_pass = 1 then')),
    );
    expect(code, contains('for update skip locked'));
    expect(code, contains("raise exception 'tur3: % için bağlayıcı metin"));
  });

  test('touch_presence_v2: tek atomik update, anon yetkisiz, giriş şart', () {
    final b = body('touch_presence_v2');
    expect(b, contains('security definer'));
    expect(b, contains('set search_path = pg_catalog, public'));
    expect(b, contains('auth.uid()'));
    expect(b, contains('returning true into v_visible'));
    expect(b, contains("interval '60 seconds'"));
    expect(
      code,
      contains(
        'revoke all on function public.touch_presence_v2() from public, anon;',
      ),
    );
    expect(
      code,
      contains(
        'grant execute on function public.touch_presence_v2() to authenticated;',
      ),
    );
  });

  test('cleanup_stale_rooms: ucuz yaş süzgeci, greatest() değişmez', () {
    expect(code, contains("r.created_at < now() - interval '30 minutes'"));
    expect(
      code,
      contains(
        "coalesce(r.started_at, r.created_at) < now() - interval '10 minutes'",
      ),
    );
    expect(index, contains("where status in ('lobby', 'active')"));
  });

  test('saklama: cron günlük, toplu, terminal durumlar; yetki kapalı', () {
    final p = body('push_outbox_retention');
    expect(p, contains("'sent', 'skipped', 'failed', 'legacy'"));
    expect(p, contains('for update skip locked'));
    expect(p, contains('security definer'));
    expect(p, contains("set search_path to 'public', 'pg_temp'"));
    final r = body('rate_limit_events_sweep');
    expect(r, contains("interval '1 day'"));
    expect(r, contains('for update skip locked'));
    for (final job in [
      "'reconcile-player-score-daily', '15 0 * * *'",
      "'push-outbox-retention', '20 0 * * *'",
      "'rate-limit-events-sweep', '25 0 * * *'",
    ]) {
      expect(code, contains(job));
    }
    expect(
      code,
      contains(
        'revoke all on function public.push_outbox_retention(integer, integer)',
      ),
    );
    expect(code, isNot(contains('to anon')));
  });

  test(
    'get_my_leaderboard_rank: pencere yok, eşitlik kırma eskisiyle aynı',
    () {
      final b = body('get_my_leaderboard_rank');
      expect(b, isNot(contains('row_number()')));
      expect(b, isNot(contains('over (')));
      // total_score, best_streak, rooms_played azalan; player_id artan.
      expect(b, contains('o.total_score > m.total_score'));
      expect(
        b,
        contains(
          'o.total_score = m.total_score and o.best_streak > m.best_streak',
        ),
      );
      expect(b, contains('o.rooms_played > m.rooms_played'));
      expect(b, contains('o.player_id < m.player_id'));
      // Engelleme süzgeci ve puanı 0 olan tabloda yok.
      expect(b, contains('blocked_users'));
      expect(b, contains('having coalesce(sum(pd.day_score), 0) > 0'));
    },
  );

  test('kilit sırası: touch kategori kilidi almaz, join yeniden dener; '
      'tetikleyici ve mutabakat (oyuncu, gün) sıralı kilitler', () {
    expect(code, contains("'public.touch_matchmaking()'"));
    expect(code, contains('perform pg_sleep(0.03)'));
    expect(code, contains('v_pass < 6'));
    expect(code, contains('order by rp.player_id'));
    expect(code, contains('v_old_day > v_new_day'));
    final b = body('reconcile_player_score_daily');
    expect(b, contains('order by x.bad, x.player_id, x.day'));
    expect(b, contains('order by t.p, t.d'));
    expect(b, contains('remaining_count'));
    expect(b, contains('score_reconcile_failures'));
  });

  test('rank: canlı gövde tabanla eşleşmezse göç durur, yedek alınır', () {
    expect(
      code,
      contains('create table if not exists public.olcek_tur3_yedek'),
    );
    expect(
      code,
      contains('get_my_leaderboard_rank canlı gövdesi beklenen tabanla'),
    );
    expect(code, contains("position('row_number() over' in v_def) = 0"));
    expect(code, contains('on conflict (ad) do nothing'));
  });

  test('mutabakat: son 2 gün, hata sayılır, günlüğe yazılır', () {
    final b = body('reconcile_player_score_daily');
    expect(b, contains('p_days integer default 2'));
    expect(b, contains('full join actual'));
    expect(b, contains('recompute_player_score_day'));
    expect(b, contains('exception when others'));
    expect(b, contains('insert into public.score_reconcile_log'));
    expect(b, contains('least(v_total, 2000)'));
    expect(
      code,
      contains(
        'alter table public.score_reconcile_log enable row level security',
      ),
    );
  });

  test('geri alma: yamaları çevirir, yeni nesneleri kaldırır', () {
    expect(geri, contains('tur3_geri2'));
    // Rank gövdesi sabit metinle değil, göç anında alınan yedekten döner.
    expect(geri, contains('olcek_tur3_yedek'));
    expect(geri, contains('yedeği yok ve canlı gövde eski değil'));
    expect(geri, contains("public.touch_matchmaking()"));
    expect(geri, contains("public.on_room_score_daily()"));
    expect(
      geri,
      contains('drop table if exists public.score_reconcile_failures'),
    );
    for (final n in [
      'reconcile_player_score_daily(integer)',
      'push_outbox_retention(integer, integer)',
      'rate_limit_events_sweep(integer)',
      'touch_presence_v2()',
    ]) {
      expect(geri, contains('drop function if exists public.$n'));
    }
    expect(geri, contains('drop table if exists public.score_reconcile_log'));
    for (final job in [
      'reconcile-player-score-daily',
      'push-outbox-retention',
      'rate-limit-events-sweep',
    ]) {
      expect(geri, contains("cron.unschedule('$job')"));
    }
  });

  test('istemci: loadRoomMessages son 50 mesajı alır (sınırsız sorgu yok)', () {
    final start = repo.indexOf('Future<List<RoomMessage>> loadRoomMessages');
    expect(start, greaterThanOrEqualTo(0));
    final end = repo.indexOf('_offline.loadRoomMessages', start);
    final fn = repo.substring(start, end);
    expect(fn, contains('.limit(PollCadence.chatWindow)'));
    expect(fn, contains('ascending: false'));
    expect(fn, contains('rows.reversed'));
  });
}
