/// `2026-11-04_olcek_sertlestirme.sql` bekçisi: 10.000 eşzamanlı kullanıcı
/// denetiminin sunucu bulguları.
///
/// ## Kusurlar
///
/// * `get_leaderboard` / `get_my_leaderboard_rank` / `get_friends_leaderboard`
///   her çağrıda BÜTÜN bitmiş odaları tarıyordu; "tüm zamanlar" büyüdükçe
///   doğrusal yavaşlar.
/// * Tek global `room-membership` advisory kilidi bütün oda kurma/katılma/
///   eşleşme çağrılarını (ve dakikalık temizliği) kullanıcılar arasında
///   sıraya diziyordu.
/// * Oda kurma ve `add_friend` için saatlik sınır yoktu; davet ve öneri
///   sayımları sayım+ekleme yarışına açıktı.
/// * `room_messages` SELECT politikası `auth.uid()`i satır başına çağırıyordu.
/// * Push uyandırması her eklemede HTTP isteği atıyor, `send-push` tek 20'lik
///   paketle çıkıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hepsi doğru sonuç veren SQL/TS'tir: hata fırlamaz, yalnız yük altında
/// yavaşlar ya da sınırı eşzamanlı çağrı aşar. Bu dosya göçü metin olarak
/// okuyup kuralları sabitler (canlı DB'ye bağlanmaz; canlı gövdeler uygulama
/// anında `pg_get_functiondef` + bağlayıcı sayımıyla doğrulanır).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File(
    'supabase/2026-11-04_olcek_sertlestirme.sql',
  ).readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-04_olcek_sertlestirme_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  final index = File(
    'supabase/functions/send-push/index.ts',
  ).readAsStringSync();
  final lib = File('supabase/functions/send-push/lib.ts').readAsStringSync();
  final libTest = File(
    'supabase/functions/send-push/lib_test.ts',
  ).readAsStringSync();

  String strip(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
  final code = strip(raw);
  final geri = strip(geriRaw);

  /// `name` fonksiyonunun gövdesi (create … sonraki `$function$;`).
  String body(String source, String name) {
    final start = source.indexOf('function public.$name(');
    expect(start, greaterThanOrEqualTo(0), reason: '$name tanımı yok');
    final end = source.indexOf(
      r'$function$;',
      source.indexOf(r'$function$', start) + 1,
    );
    return source.substring(start, end);
  }

  test('tek işlemde, küçük harfli begin/commit; büyük harfli COMMIT yok', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(
      applied,
      contains('2026-11-04_olcek_sertlestirme.sql | ⏳'),
      reason: 'uygulanana dek ⏳',
    );
  });

  test('canlı gövdeler okunup bağlayıcı TAM BİR kez bulunmazsa göç durur', () {
    expect(code, contains('pg_get_functiondef'));
    expect(code, contains('(1 beklenir)'));
    expect(code, contains('if position(p_yeni in v_def) > 0'));
    // Global kilit kalan işlev varsa göç düşer.
    expect(code, contains('global room-membership kilidi kalan işlevler'));
  });

  test('global üyelik kilidi kullanıcı başına kilide iner', () {
    for (final sig in [
      'create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
      'join_room_by_code(text)',
      'join_matchmaking(text)',
      'delete_my_account()',
      'create_room_rematch(uuid)',
    ]) {
      expect(code, contains("'public.$sig'"), reason: '$sig yamalanmalı');
    }
    expect(
      code,
      contains("'room-membership:' || v_uid::text"),
      reason: 'oda kurma/katılma/rövanş kullanıcı başına',
    );
    expect(code, contains("'room-membership:' || v_player_id::text"));
    expect(code, contains("'room-membership:' || v_user_id::text"));
    // Eşleşme: rakibin kilidi BEKLEMEDEN denenir, canlı oda yeniden bakılır.
    expect(code, contains('pg_try_advisory_xact_lock('));
    expect(code, contains("''room-membership:'' || v_opponent::text"));
    // Temizlik işlevi üyelik kabul etmez: kilit kalkar.
    // Rövanş: kullanıcı kilidi kaynak oda for update'inden ÖNCE.
    expect(code, contains("'public.create_room_rematch(uuid)'"));
    expect(
      code,
      contains(
        "perform pg_advisory_xact_lock(hashtextextended(''room-membership:'' || v_uid::text, 0));\\n\\n'",
      ),
    );
    expect(code, contains("'public.cleanup_stale_rooms()'"));
    expect(code, contains('perform 1;'));
  });

  test('hız sınırları: oda 30/saat, arkadaş ekleme 50/saat, race-safe', () {
    final f = body(code, 'rate_limit_hit');
    expect(f, contains('security definer'));
    expect(f, contains("set search_path to 'public', 'pg_temp'"));
    expect(f, contains('pg_advisory_xact_lock('));
    expect(
      f.indexOf('pg_advisory_xact_lock('),
      lessThan(f.indexOf('select count(*)')),
      reason: 'kilit sayımdan ÖNCE',
    );
    expect(f.indexOf('select count(*)'), lessThan(f.indexOf('insert into')));
    expect(f, contains('if v_uid is null'));
    expect(code, contains("rate_limit_hit(''room_create'', 30"));
    expect(code, contains("rate_limit_hit(''add_friend'', 50"));
    // Oda sınırı mevcut-oda dönüşünden SONRA (ağ tekrarı sayılmaz).
    expect(code, contains('  loop\\n    v_attempt := v_attempt + 1;'));
    // Davet ve öneri sayımı kilitli.
    expect(code, contains("''invite:'' || v_uid::text"));
    final trg = body(code, 'limit_suggested_question_rate');
    expect(trg.indexOf("'suggest:' || new.user_id::text"), greaterThan(0));
    expect(
      trg.indexOf('pg_advisory_xact_lock('),
      lessThan(trg.indexOf('select count(*)')),
    );
    expect(trg, contains("errcode = 'zk429'"));
  });

  test('room_messages politikası auth.uid()i bir kez hesaplar + indeks', () {
    final start = code.indexOf('create policy room_messages_member_select');
    expect(start, greaterThanOrEqualTo(0));
    final policy = code.substring(start, code.indexOf(';', start));
    expect(RegExp(r'\(select auth\.uid\(\)\)').allMatches(policy).length, 3);
    expect(
      policy.replaceAll('(select auth.uid())', ''),
      isNot(contains('auth.uid()')),
      reason: 'çıplak auth.uid() kalmamalı',
    );
    expect(policy, contains('to authenticated'));
    expect(policy, contains('blocked_users'));
    expect(code, contains('on public.room_messages (room_id, created_at)'));
  });

  test('sıralama: günlük toplam tablosu, tetikleyici, geri doldurma', () {
    expect(
      code,
      contains('create table if not exists public.player_score_daily'),
    );
    expect(code, contains('primary key (player_id, day)'));
    expect(
      code,
      contains(
        'alter table public.player_score_daily enable row level security',
      ),
    );
    expect(
      code,
      contains(
        'revoke all on public.player_score_daily from public, anon, authenticated',
      ),
    );
    expect(code, contains('create trigger trg_rooms_score_daily'));
    expect(code, contains('after update of status, ended_reason, finished_at'));
    // rooms üzerinde tablo düzeyi kilit/indeks YOK; geri doldurma upsert,
    // tetikleyici ondan SONRA, yakalama kilit altında.
    expect(code, isNot(contains('lock table')));
    expect(code, isNot(contains('on public.rooms (')));
    final backfill = code.indexOf('on conflict (player_id, day) do nothing');
    final trig = code.indexOf('create trigger trg_rooms_score_daily');
    final catchUp = code.indexOf('from olcek_baslangic');
    expect(backfill, greaterThan(0));
    expect(trig, greaterThan(backfill));
    expect(catchUp, greaterThan(trig));
    expect(code, contains("hashtextextended('score-daily:'"));
    // finished_at boş bitmiş odalar yalnız tüm zamanlara girer.
    expect(code, contains("'-infinity'::date"));
    expect(
      File(
        'supabase/2026-11-04_olcek_indeks_concurrently.sql',
      ).readAsStringSync(),
      contains(
        'create index concurrently if not exists idx_rooms_finished_at_finished',
      ),
    );
    // Tetikleyici hatası oyun bitişini bozmaz.
    final trg = body(code, 'on_room_score_daily');
    expect(trg, contains('exception when others'));
    expect(trg, contains('raise warning'));
    // Eski süzgeçler korunur; günlük tavan yok.
    final rec = body(code, 'recompute_player_score_day');
    expect(rec, contains("r.status = 'finished'"));
    expect(
      rec,
      contains("coalesce(r.ended_reason, 'completed') = 'completed'"),
    );
    expect(rec, contains("'europe/istanbul'"));
    expect(code, isNot(contains('5000')), reason: 'günlük 5000 tavanı dönmez');
  });

  test('üç sıralama işlevi toplamdan okur; şekil ve yetki aynı', () {
    for (final fn in [
      'get_leaderboard',
      'get_my_leaderboard_rank',
      'get_friends_leaderboard',
    ]) {
      final f = body(code, fn);
      expect(f, contains('leaderboard_daily_rows('), reason: fn);
      expect(
        f,
        isNot(contains('public.room_players')),
        reason: '$fn ham tarama',
      );
      expect(f, contains('security definer'));
      expect(f, contains("set search_path to 'public'"));
    }
    expect(
      body(code, 'get_leaderboard'),
      contains('limit least(greatest(p_limit, 1), 100)'),
    );
    expect(
      code,
      contains(
        'revoke all on function public.get_leaderboard(integer, integer) from public, anon',
      ),
    );
    expect(
      code,
      contains(
        'grant execute on function public.get_friends_leaderboard(integer) to authenticated',
      ),
    );
    // Pencere: kısmi sınır günü ham, tam günler toplamdan.
    final helper = body(code, 'leaderboard_daily_rows');
    expect(helper, contains('now() - make_interval(days => p_days)'));
    expect(helper, contains('a.day > e.d'));
    expect(helper, contains('r.finished_at >= e.ts'));
  });

  test(
    'yeni iç işlevler anon/authenticated için kapalı; doğrulama bloğu var',
    () {
      for (final fn in [
        'rate_limit_hit(text, integer, interval)',
        'recompute_player_score_day(uuid, date)',
        'on_room_score_daily()',
        'rebuild_player_score_daily(date)',
        'leaderboard_daily_rows(integer, uuid[])',
      ]) {
        expect(
          code,
          contains(
            'revoke all on function public.$fn\n  from public, anon, authenticated',
          ),
          reason: fn,
        );
      }
      expect(code, contains('istemciye açık olmamalı'));
      expect(code, contains("has_function_privilege('anon'"));
      for (final name in [
        'rate_limit_hit',
        'recompute_player_score_day',
        'on_room_score_daily',
        'rebuild_player_score_daily',
        'leaderboard_daily_rows',
        'limit_suggested_question_rate',
      ]) {
        final f = body(code, name);
        expect(f, contains('security definer'), reason: name);
        expect(
          f,
          contains("set search_path to 'public', 'pg_temp'"),
          reason: name,
        );
      }
    },
  );

  test('push uyandırması 2 sn sönümlenir; koşullu güncelleme atomik', () {
    expect(code, contains('add column if not exists last_wake_at timestamptz'));
    final start = code.indexOf(
      'create or replace function public.wake_push_delivery_v2',
    );
    final wake = code.substring(start, code.indexOf(r'$wake$;', start + 100));
    expect(wake, contains("interval '2 seconds'"));
    expect(wake, contains('update public.push_delivery_v2_config'));
    expect(wake, contains('if not found then return false'));
    expect(
      wake.indexOf('update public.push_delivery_v2_config'),
      lessThan(wake.indexOf('net.http_post')),
      reason: 'HTTP isteğinden önce yuva alınır',
    );
    expect(wake, contains('security definer'));
    expect(wake, contains('exception when others'));
    expect(
      code,
      contains(
        'revoke all on function public.wake_push_delivery_v2() from public, anon, authenticated, service_role',
      ),
    );
  });

  test('send-push paket döngüsü: boşalana ya da bütçe dolana dek, ack aynı', () {
    expect(index, contains('shouldClaimNextBatch('));
    expect(index, contains('CLAIM_BUDGET_MS = 25_000'));
    expect(index, contains('BATCH_LIMIT = 20'));
    expect(index, contains('claim_push_outbox_v2'));
    expect(index, contains('finish_push_outbox'));
    expect(index, contains('if (jobs.length === 0) break;'));
    expect(lib, contains('export function shouldClaimNextBatch'));
    expect(libTest, contains('shouldClaimNextBatch'));
    // İlk talep hatası eskisi gibi 500; sonraki hata önceki paketleri bozmaz.
    expect(
      index,
      contains(
        'if (counts.batches === 0) return json({ error: "claim_failed" }, 500)',
      ),
    );
  });

  test('geri alma: yamaları geri çevirir, yeni nesneleri kaldırır', () {
    expect(geri, contains('olcek_geri'));
    expect(geri, contains('drop trigger if exists trg_rooms_score_daily'));
    expect(geri, contains('drop table if exists public.player_score_daily'));
    expect(geri, contains('drop table if exists public.rate_limit_events'));
    expect(geri, contains('drop column if exists last_wake_at'));
    expect(geri, contains("hashtextextended('room-membership', 0)"));
    expect(geri, contains('create or replace function public.get_leaderboard'));
    expect(geri, contains('create policy room_messages_member_select'));
    expect(
      geri,
      contains('create or replace function public.wake_push_delivery_v2'),
    );
  });
}
