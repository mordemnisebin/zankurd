/// 2026-11-16 seri dondurma sunucu üst sınırı: sözleşme bekçisi (W3, alan 3 #4).
///
/// ## Kusur
///
/// Üst sınır (2 jeton) yalnız istemcide denetleniyordu; iki cihaz aynı anda
/// 50'şer jeton ödeyince iki ücret kesilip bulut birleşimi bakiyeyi 2'ye
/// kıstırınca bir hak eriyordu.
///
/// ## Niçin sessizdi
///
/// Her cihaz kendi yerelinde "2'den az" görür; çakışma yalnız ikisi aynı
/// hesapta eşitlenince ortaya çıkar. Davranışı PGlite bekçisi
/// (`tool/test_seri_dondurma_ust_sinir_local.mjs`) sınar; bu dosya kuralların
/// YERİNDE durduğunu korur: sunucu sınırı = istemci sınırı, istemci mağaza
/// anahtarını sunucunun tanıdığı önekle gönderir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  late String sql;

  setUpAll(
    () => sql = _read('supabase/2026-11-16_seri_dondurma_ust_sinir.sql'),
  );

  test('sunucu sınırı istemci sınırıyla aynı', () {
    final cap = RegExp(
      r'v_cap constant integer := (\d+)',
    ).firstMatch(sql)!.group(1);
    expect(int.parse(cap!), StreakStore.maxFreeze);
    expect(StreakStore.maxFreeze, SnapshotStreak.maxFreeze);
  });

  test('sunucu, istemcinin gönderdiği anahtar önekini sayar', () {
    expect(shopFreezeKeyPrefix, 'shop_freeze_');
    expect(sql, contains(r"streak_freeze:shop\_freeze\_%"));
  });

  test('göç yalnız yeni nesne yaratır ve eski işleve dokunmaz', () {
    expect(sql, contains('create function public.spend_streak_freeze_capped'));
    expect(
      sql,
      isNot(contains('create or replace function public.spend_streak_freeze(')),
    );
    expect(sql, contains('seri_mevcut'));
    expect(
      sql,
      contains(
        'revoke all on function public.spend_streak_freeze_capped(text) '
        'from public, anon',
      ),
    );
  });

  test('sınırlı işlev eski işlevle AYNI advisory kilidi kullanır', () {
    final old = _read('supabase/2026-08-03_streak_freeze_idempotency.sql');
    const lock = 'pg_advisory_xact_lock(hashtextextended(v_uid::text, 0))';
    expect(old, contains(lock));
    expect(sql, contains(lock));
  });

  test('istemci sınırlı işlevi çağırır; `freeze_full` kesin ret', () {
    final repo = _read('lib/src/data/supabase_zankurd_repository.dart');
    expect(repo, contains("'spend_streak_freeze_capped'"));
    expect(repo, contains("response['error'] == 'freeze_full'"));
    final shop = _read('lib/src/screens/shop_screen.dart');
    expect(shop, contains('StreakFreezeChargeOutcome.full'));
    expect(shop, contains('PendingOperationStore'));
  });
}
