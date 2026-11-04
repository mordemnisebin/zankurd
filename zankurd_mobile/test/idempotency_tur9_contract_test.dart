/// 2026-11-07 idempotency turu: sunucu göçü ve istemci bağlantısı sözleşmesi.
///
/// ## Kusur
///
/// Çark dönüşü ve düello oluşturma sunucuda işlenip yanıtı kaybolursa yeniden
/// deneme YENİ işlem sayılıyordu (satın alınmış ek çark hakkı yanıyor, ikinci
/// düello açılıyordu). Çözüm sunucuda işlem kimliği; build 43 ise eski imzalarla
/// çalışmaya devam etmek zorunda.
///
/// ## Niçin sessiz kalırdı
///
/// Yeni işlev eklense bile istemci eski çağrıya düşebilir (ya da göç eski
/// işlevi yamalayıp build 43'ü kırabilir); iki yarı ayrı ayrı "çalışır" görünür.
/// Davranışı PGlite bekçisi (`tool/test_idempotency_tur9_local.mjs`) sınar; bu
/// dosya kuralların YERİNDE durduğunu korur.
///
/// ## Kural
///
/// * Göç YALNIZ yeni nesne yaratır; `award_spin_coins`, `claim_extra_spin`,
///   `start_async_duel(text)`, `create_async_duel_challenge(text,uuid)` gövdesine
///   dokunmaz.
/// * İstemci kimliği çağrıdan ÖNCE kalıcı yazar, yalnız kesin yanıtta siler; yeni
///   işlev yoksa (PGRST202) eski yola düşer.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _sql(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'--[^\n]*'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();

void main() {
  late String sql;
  late String rollback;
  late String repo;

  setUpAll(() {
    sql = _sql('supabase/2026-11-07_idempotency_tur9.sql');
    rollback = _sql('supabase/geri_al/2026-11-07_idempotency_tur9_geri.sql');
    repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
  });

  test('göç yalnız YENİ nesne yaratır, mevcut işlevleri yeniden tanımlamaz', () {
    final created = RegExp(
      r'create (?:or replace )?function (public\.\w+)\(([^)]*)\)',
    ).allMatches(sql).map((m) => m.group(1)).toList();
    expect(created, [
      'public.spin_wheel_once',
      'public.start_async_duel',
      'public.create_async_duel_challenge',
    ]);
    // "or replace" yok: var olan bir imzanın üstüne yazılırsa göç hata verir.
    expect(sql, isNot(contains('create or replace function')));
    expect(
      sql,
      contains(
        'create function public.start_async_duel(p_category text, p_request_id uuid)',
      ),
    );
    expect(
      sql,
      contains(
        'create function public.create_async_duel_challenge( p_category text, p_friend_id uuid, p_request_id uuid)',
      ),
    );
  });

  test('yeni parametreler ZORUNLU imza farkıdır, eski çağrıyı bozmaz', () {
    // Varsayılanlı yeni parametre eski `start_async_duel(text)` çağrısını
    // belirsiz kılardı (PostgREST aşırı yükleme seçimi): varsayılan YOK.
    expect(sql, isNot(contains('p_request_id uuid default')));
    expect(sql, isNot(contains('p_request_id uuid = ')));
  });

  test('kayıt defteri istemciye kapalı, işlevler definer ve anon kapalı', () {
    expect(
      sql,
      contains('alter table public.idempotent_ops enable row level security'),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.idempotent_ops from public, anon, authenticated',
      ),
    );
    expect(sql, contains('primary key (user_id, op_key)'));
    expect(sql, contains('security definer'));
    expect(sql, contains("set search_path to 'public', 'pg_temp'"));
    expect(
      sql,
      contains(
        'revoke all on function public.spin_wheel_once(text) from public, anon',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.start_async_duel(text, uuid) from public, anon',
      ),
    );
  });

  test(
    'tekrar çağrı kayıttan döner; kesin ret KAYDEDİLMEZ; eşzamanlılık kilitli',
    () {
      expect(sql, contains('pg_advisory_xact_lock'));
      expect(sql, contains("'replayed', true"));
      // Hak yok dönüşü insert'ten ÖNCE çıkar.
      expect(
        sql.indexOf("'no_spins', true"),
        lessThan(
          sql.indexOf(
            "insert into public.idempotent_ops (user_id, op_key, kind, result) values (v_uid, 'spin:'",
          ),
        ),
      );
    },
  );

  test('göç öncesi/sonrası ve geri alma ön koşulları var', () {
    expect(sql, contains('yaratılacak nesnelerden biri zaten var; göç durdu'));
    expect(sql, contains('mevcut bir işlevin gövdesi değişti'));
    expect(sql, contains('tur9_mevcut'));
    expect(
      rollback,
      contains('drop function if exists public.spin_wheel_once(text)'),
    );
    expect(
      rollback,
      contains('drop function if exists public.start_async_duel(text, uuid)'),
    );
    expect(rollback, contains('drop table if exists public.idempotent_ops'));
    expect(rollback, isNot(contains('create or replace')));
  });

  test(
    'çark: kimlik çağrıdan ÖNCE kalıcı yazılır, yalnız kesin yanıtta silinir',
    () {
      final once = repo.indexOf('Future<int?> _awardSpinOnce()');
      expect(once, greaterThan(0));
      final body = repo.substring(
        once,
        repo.indexOf('Future<void> _markSpunToday()'),
      );
      expect(
        body.indexOf("PendingOperationStore.idFor('spin'"),
        lessThan(body.indexOf("'spin_wheel_once'")),
      );
      expect(body, contains("'p_idempotency_key': key"));
      // Taşıma hatası kimliği SİLMEZ (yeniden deneme aynı kimlikle gider).
      expect(body, contains('rethrow; // Kimlik KALIR'));
      // Eski iki çağrılı yol yalnız işlev yokken kullanılır.
      expect(body, contains('_spinOnceSupported = false'));
      expect(repo, contains('final once = await _awardSpinOnce();'));
    },
  );

  test(
    'düello: istek kimliği kalıcı, eski çağrıya düşüş yalnız işlev yokken',
    () {
      final at = repo.indexOf('Future<AsyncDuelStart> _createDuelOnce(');
      expect(at, greaterThan(0));
      final body = repo.substring(
        at,
        repo.indexOf('Future<AsyncDuelStart> startAsyncDuel('),
      );
      expect(
        body.indexOf('PendingOperationStore.idFor('),
        lessThan(body.indexOf("'p_request_id': requestId")),
      );
      expect(body, contains('isMissingRpcError(error)'));
      expect(body, contains('_duelRequestIdSupported = false'));
      expect(repo, contains("kind: 'duel_start'"));
      expect(repo, contains("kind: 'duel_challenge'"));
      // Yanıt başarıyla ayrıştırıldıktan SONRA silinir.
      expect(
        body.indexOf('AsyncDuelStart.fromJson'),
        lessThan(body.lastIndexOf('PendingOperationStore.clear')),
      );
    },
  );

  test('görev XP: işlem kimliğiyle verilir', () {
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(
      home,
      contains('operationId: missionStore.claimOperationId(mission)'),
    );
  });

  test('açılışta seri onarımı niyeti uzlaştırılır', () {
    final shell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    expect(shell, contains('StreakRepairService.recoverPending('));
  });
}
