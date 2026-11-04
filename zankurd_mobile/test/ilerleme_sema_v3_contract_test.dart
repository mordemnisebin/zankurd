/// 2026-11-10 ilerleme şema sürümü 2: sunucu göçü ve istemci bağlantısı sözleşmesi.
///
/// ## Kusur
///
/// Anlık görüntüye `words` eklenirken sürüm artmamıştı ve sunucu "daha eski
/// şemalı yazım yeni şemalı kaydı ezemez" kuralını hiçbir yolda uygulamıyordu;
/// boyut sınırı ise İSTİSNA ile reddediliyor, istemci bütün yedeği bırakıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Eski ve yeni istemci tek başına çalışır; ezme yalnız ikisi aynı hesapta
/// eşitlenince görünür. Davranışı PGlite bekçisi
/// (`tool/test_ilerleme_sema_v3_local.mjs`) sınar; bu dosya kuralların YERİNDE
/// durduğunu korur.
///
/// ## Kural
///
/// * Göç YALNIZ yeni nesne yaratır; `get_my_progress`, `save_my_progress`,
///   `save_my_progress_v2` gövdesine dokunmaz (build 45 ve öncesi çalışır).
/// * Tetikleyici HER yazım yolunu korur; v3 aynı advisory kilidi kullanır.
/// * İstemci v3'ü dener, yoksa v2'ye düşer; `too_large` "böl ve yeniden gönder"dir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';

String _sql(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'--[^\n]*'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();

void main() {
  late String sql;
  late String rollback;
  late String sync;

  setUpAll(() {
    sql = _sql('supabase/2026-11-10_ilerleme_sema_v3.sql');
    rollback = _sql('supabase/geri_al/2026-11-10_ilerleme_sema_v3_geri.sql');
    sync = File('lib/src/data/progress_sync.dart').readAsStringSync();
  });

  test(
    'göç yalnız YENİ nesne yaratır, mevcut işlevleri yeniden tanımlamaz',
    () {
      final created = RegExp(
        r'create (?:or replace )?function (public\.\w+)\(',
      ).allMatches(sql).map((m) => m.group(1)).toList();
      expect(created, [
        'public.progress_snapshot_version',
        'public.player_progress_schema_guard',
        'public.save_my_progress_v3',
      ]);
      expect(sql, isNot(contains('create or replace function')));
      expect(sql, contains('mevcut bir işlevin gövdesi değişti'));
      expect(sql, contains('sema_mevcut'));
    },
  );

  test('tetikleyici UPDATE öncesi satır başına, eski şemayı durdurur', () {
    expect(
      sql,
      contains(
        'create trigger player_progress_schema_guard before update of snapshot on public.player_progress for each row',
      ),
    );
    expect(
      sql,
      contains('progress snapshot schema is older than the stored one'),
    );
  });

  test('v3 aynı kilit anahtarını kullanır ve yapısal ret döner', () {
    expect(sql, contains("hashtextextended('progress:' || v_uid::text, 0)"));
    expect(sql, contains("'too_large', true"));
    expect(sql, contains("'stale_schema', true"));
    // Boyut reddi kilitten ve yazımdan ÖNCE.
    expect(
      sql.indexOf("'too_large', true"),
      lessThan(sql.indexOf('pg_advisory_xact_lock')),
    );
  });

  test('yetkiler: v3 yalnız authenticated; yardımcılar istemciye kapalı', () {
    expect(sql, contains('security definer'));
    expect(sql, contains("set search_path to 'public', 'pg_temp'"));
    expect(
      sql,
      contains(
        'revoke all on function public.save_my_progress_v3(jsonb, timestamptz) from public, anon',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.progress_snapshot_version(jsonb) from public, anon, authenticated',
      ),
    );
  });

  test('geri alma yalnız yeni nesneleri kaldırır', () {
    expect(
      rollback,
      contains(
        'drop trigger if exists player_progress_schema_guard on public.player_progress',
      ),
    );
    expect(
      rollback,
      contains('drop function if exists public.save_my_progress_v3'),
    );
    expect(rollback, isNot(contains('create or replace')));
    expect(
      rollback,
      isNot(contains('drop function if exists public.save_my_progress_v2')),
    );
  });

  test(
    'istemci: v3 önce, v2 yedek; too_large ve eski sunucu istisnası "böl"',
    () {
      expect(sync, contains("'save_my_progress_v3'"));
      expect(
        sync.indexOf("'save_my_progress_v3'"),
        lessThan(sync.indexOf("'save_my_progress_v2'")),
      );
      expect(sync, contains("response['too_large'] == true"));
      expect(sync, contains("contains('Snapshot too large')"));
      expect(sync, contains('on ProgressTooLarge'));
      expect(sync, contains('coreOnly: true'));
    },
  );

  test('sürüm sabiti sunucu göçüyle birlikte 2; sunucu v>=2 kaydını korur', () {
    expect(ProgressSnapshot.currentVersion, 2);
    expect(const ProgressSnapshot().toJson()['v'], 2);
  });
}
