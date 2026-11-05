/// 2.1.2 W3 tur 2 bekçileri (Copilot incelemesi sonrası düzeltmeler).
///
/// 1. Düello görev yeniden denemesi hesap değişince başka hesabın günlüğüne yazardı.
/// 2. Dondurma alımı beklemelerden sonra sahibi doğrulamaz, A'nın hakkı B'ye eklenirdi.
/// 3. Bekleyen işlem kimliği 24 saatte biterdi; sunucu 14 gün saklar: belirsiz
///    alım yeni kimlikle ÇİFT tahsil edilirdi.
/// 4. Build 45'in kapsamsız bekleyen düello kimliği taşınmazdı: güncelleme sonrası
///    yeniden deneme çift düello açardı.
/// 7. Hikâye düğüm yazımının sonucu denetlenmezdi: reddedilen yazım başarı görünürdü.
///
/// Niçin sessizdi: hepsi yalnız "yazım/hesap/zaman" kenarında görünür; bellek sahte
/// deposu ve tek hesaplı testler kusuru göstermez.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/pending_operation_store.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/utils/client_round_id.dart';

class _FailingStore extends SharedPreferencesStorePlatform {
  _FailingStore(this.values);
  final Map<String, Object> values;
  final failing = <String>{};
  bool failAll = false;

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failAll || failing.any(key.contains)) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

String _read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform original;

  setUp(() {
    original = SharedPreferencesStorePlatform.instance;
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    StoryProgressStore.resetInstance();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = original;
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });

  group('#3 kimlik ömrü sunucu saklamasıyla uyumlu', () {
    test('belirsiz kalmış kimlik 5 gün sonra AYNI kimlikle gider', () async {
      final t0 = DateTime(2026, 11, 5, 10);
      final a = await PendingOperationStore.idFor('shop_freeze', 'u1', now: t0);
      final later = await PendingOperationStore.idFor(
        'shop_freeze',
        'u1',
        now: t0.add(const Duration(days: 5)),
      );
      expect(later, a, reason: '24 saatte yenilenseydi çift tahsil olurdu');
    });

    test('sunucunun 14 günlük saklamasından SONRA yeni kimlik', () async {
      final t0 = DateTime(2026, 11, 5, 10);
      final a = await PendingOperationStore.idFor('shop_freeze', 'u1', now: t0);
      final later = await PendingOperationStore.idFor(
        'shop_freeze',
        'u1',
        now: t0.add(const Duration(days: 14)),
      );
      expect(later, isNot(a));
      expect(
        PendingOperationStore.defaultMaxAge,
        lessThan(const Duration(days: 14)),
      );
    });

    test('günlük çark kısa ömrü AÇIKÇA verir', () {
      final repo = _read('lib/src/data/supabase_zankurd_repository.dart');
      expect(repo, contains('maxAge: PendingOperationStore.shortMaxAge'));
    });
  });

  group('#4 build 45 kapsamsız düello kimliği taşınır', () {
    test(
      'aynı kapsamdaki eski kayıt yeni anahtara taşınır, eski silinir',
      () async {
        final legacyId = newClientRoundId();
        final at = DateTime.now().millisecondsSinceEpoch;
        SharedPreferences.setMockInitialValues({
          'zankurd.pendingOp.duel_start.u1': jsonEncode({
            'id': legacyId,
            'scope': 'Tarih',
            'at': at,
          }),
        });
        final id = await PendingOperationStore.idFor(
          'duel_start',
          'u1',
          scope: 'Tarih',
        );
        expect(id, legacyId, reason: 'çift düello açılmamalı');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('zankurd.pendingOp.duel_start.u1'), isNull);
        expect(
          prefs.getKeys().where((k) => k.contains('duel_start')),
          hasLength(1),
        );
      },
    );

    test('başka kapsamın eski kaydı alınmaz ve yerinde kalır', () async {
      final legacyId = newClientRoundId();
      SharedPreferences.setMockInitialValues({
        'zankurd.pendingOp.duel_start.u1': jsonEncode({
          'id': legacyId,
          'scope': 'Tarih',
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      });
      final id = await PendingOperationStore.idFor(
        'duel_start',
        'u1',
        scope: 'Coğrafya',
      );
      expect(id, isNot(legacyId));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zankurd.pendingOp.duel_start.u1'), isNotNull);
    });
  });

  group('#7 hikâye düğüm yazımı sonucu denetlenir', () {
    test('düğüm yazımı reddedilirse fırlatır ve bellek geri alınır', () async {
      final store0 = _FailingStore({});
      SharedPreferencesStorePlatform.instance = store0;
      SharedPreferences.resetStatic();
      LocalProgressScope.bind('A');
      final store = await StoryProgressStore.load();
      await store.saveNode('s1', 'n1');
      store0.failing.add('zankurd.story.s1');
      await expectLater(store.saveNode('s1', 'n2'), throwsStateError);
      expect(store.currentNodeId('s1'), 'n1');
    });

    test(
      'üst veri yazımı reddedilirse fırlatır, düğüm eski değere döner',
      () async {
        final store0 = _FailingStore({});
        SharedPreferencesStorePlatform.instance = store0;
        SharedPreferences.resetStatic();
        LocalProgressScope.bind('A');
        final store = await StoryProgressStore.load();
        await store.saveNode('s1', 'n1');
        store0.failing.add('storyMeta');
        await expectLater(store.saveNode('s1', 'n2'), throwsStateError);
        expect(store.currentNodeId('s1'), 'n1');
        expect(
          store0.values.entries
              .firstWhere((e) => e.key.endsWith('zankurd.story.s1'))
              .value,
          'n1',
          reason: 'diskteki düğüm de eskiye döner',
        );
      },
    );
  });

  group('#1 #2 hesap değişimi (kaynak sözleşmesi)', () {
    test(
      'düello görev yeniden denemesi sahibi sabitler, hesap değişince bırakır',
      () {
        final src = _read(
          'lib/src/screens/async_duel/async_duel_play_screen.dart',
        );
        expect(src, contains('_missionOwner'));
        expect(src, contains('_missionAbandoned = true'));
        expect(
          RegExp(r'LocalProgressScope\.activeUserId != owner').allMatches(src),
          hasLength(2),
          reason: 'load() ÖNCESİ ve SONRASI doğrulanmalı',
        );
      },
    );

    test('dondurma alımı her beklemeden sonra sahibi doğrular', () {
      final src = _read('lib/src/screens/shop_screen.dart');
      expect(
        RegExp(r'!sameOwner\(\)').allMatches(src).length,
        greaterThanOrEqualTo(5),
      );
      // Bekleyen kimlik alındıktan sonra, RPC'den ÖNCE doğrulama.
      final check = src.indexOf(
        'if (!sameOwner()) return;\n      final charge',
      );
      expect(check, isNonNegative);
    });
  });

  group('#5 GUARD göçü', () {
    test('göç tam gövde md5 düzenini ve geri almayı taşır', () {
      final sql = _read(
        'supabase/2026-11-17_seri_dondurma_eski_rpc_koruma.sql',
      );
      expect(sql, contains('v_taban constant text'));
      expect(sql, contains("'guard_seri:'"));
      expect(sql, contains('spend_streak_freeze_capped(p_idempotency_key)'));
      final rollback = _read(
        'supabase/geri_al/2026-11-17_seri_dondurma_eski_rpc_koruma_geri.sql',
      );
      expect(rollback, contains('md5(v_eski) <> v_md5'));
      expect(
        _read('tool/sql_ve_python_testleri.sh'),
        contains('test_seri_dondurma_eski_rpc_koruma_local'),
      );
      expect(
        _read('supabase/applied.md'),
        contains('2026-11-17_seri_dondurma_eski_rpc_koruma.sql'),
      );
    });
  });
}
