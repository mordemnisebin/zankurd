// ignore_for_file: depend_on_referenced_packages
// R9 (GPT-6 Pro alan 2) hesap sahipliği ve yazım bekçileri.
//
// 1) Kuyruğa alma BAŞLATAN hesabı bilmiyordu: A'nın joker borcu / ders
//    tamamlaması istek sürerken B'ye geçilince B'nin kuyruğuna yazılıyordu.
//    Sessizdi: kuyruk denetimi yalnız "şimdiki kullanıcı = kuyruk sahibi"ne
//    bakar, ikisi de B olduğundan geçiyordu.
// 2) MistakeStore her yazımda anahtarı o anki hesaptan türetiyordu: A'nın
//    üç ayrı yazımı arasında B'ye geçilirse kalan yazımlar B'nin
//    anahtarlarına gidiyordu.
// 3) LevelProgressStore yazım sonucunu okumuyordu: disk yazmasa da seviye
//    "geçildi" ve sonraki kilit açık görünüyordu.
// 4) Sunucu günü İstanbul'dur; paylaşım ödülü kapısı yerel takvimi kullanıyordu.
// 5) Eşitleme kuyruğu geçici hatadan sonra kendiliğinden yeniden denenmiyordu.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/utils/result_sharer.dart';

class _DeadHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw Exception('injected');
}

class _Online implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.wifi,
  ];
}

class _Repo extends SupabaseZanKurdRepository {
  _Repo(this.userId)
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _DeadHttp(),
        ),
      );

  String? userId;

  @override
  String? get currentUserId => userId;
}

class _FailingWriteStore extends SharedPreferencesStorePlatform {
  @override
  Future<Map<String, Object>> getAll() async => {};

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;

  @override
  Future<bool> remove(String key) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    MistakeStore.resetInstance();
    await SyncManager.resetForTesting();
  });

  group('kuyruk başlatan hesabı bilir', () {
    test('joker borcu: sahip uyuşmazsa B kuyruğuna yazılmaz', () async {
      LocalProgressScope.bind('user-b');
      final repo = _Repo('user-b');
      final manager = await SyncManager.initialize(
        repo,
        connectivityMonitor: _Online(),
      );
      await expectLater(
        manager.queueCoinSpend(
          amount: 20,
          reason: 'wildcard',
          idempotencyKey: 'k1',
          expectedOwner: 'user-a',
        ),
        throwsStateError,
      );
      expect(manager.pendingCount, 0);
      // Sahip uyuşunca normal çalışır.
      await manager.queueCoinSpend(
        amount: 20,
        reason: 'wildcard',
        idempotencyKey: 'k2',
        expectedOwner: 'user-b',
      );
      expect(manager.pendingCount, 1);
    });

    test('ders tamamlama: sahip uyuşmazsa B adına kuyruğa girmez', () async {
      LocalProgressScope.bind('user-b');
      final manager = await SyncManager.initialize(
        _Repo('user-b'),
        connectivityMonitor: _Online(),
      );
      await expectLater(
        manager.queueLessonCompletion('lesson-1', expectedOwner: 'user-a'),
        throwsStateError,
      );
      expect(manager.pendingCount, 0);
    });
  });

  group('MistakeStore anahtarları oluşturulurken sabitlenir', () {
    test(
      'yazım sürerken hesap değişirse yeni hesabın anahtarlarına HİÇ dokunulmaz',
      () async {
        LocalProgressScope.bind('user-a');
        final store = await MistakeStore.load();
        LocalProgressScope.bind('user-b');
        await store.markMistake('qa1');

        // Sahip değişti: yazım kilit altında reddedilir (A'nın kaydı bu turda
        // düşer, kullanıcıya "kaydedilemedi" gösterilir) ama B'nin verisi
        // ezilmez.
        final prefs = await SharedPreferences.getInstance();
        for (final logical in [
          'zankurd.mistakeQuestionIds',
          'zankurd.mistakeMetadata',
          'zankurd.dailyPerformance',
        ]) {
          final key = LocalProgressScope.physicalFor('user-b', logical);
          expect(prefs.get(key), isNull, reason: logical);
        }
      },
    );

    test('hesap değişmediyse yazım A anahtarlarına gider', () async {
      LocalProgressScope.bind('user-a');
      final store = await MistakeStore.load();
      await store.markMistake('qa1');
      final prefs = await SharedPreferences.getInstance();
      final aIds = LocalProgressScope.physicalFor(
        'user-a',
        'zankurd.mistakeQuestionIds',
      );
      expect(prefs.getStringList(aIds), contains('qa1'));
    });
  });

  group('LevelProgressStore yazım sonucunu okur', () {
    test('disk yazmazsa seviye geçildi sayılmaz (fırlatır)', () async {
      final original = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = original;
        SharedPreferences.setMockInitialValues({});
        LevelProgressStore.resetInstance();
      });
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _FailingWriteStore();
      LevelProgressStore.resetInstance();
      final store = await LevelProgressStore.load();
      await expectLater(
        store.recordResult('Ziman', null, 1, correct: 9, total: 10),
        throwsStateError,
      );
      await expectLater(
        store.recordResult('Ziman', null, 1, correct: 1, total: 10),
        throwsStateError,
      );
    });
  });

  group('paylaşım ödülü günü İstanbul takvimidir', () {
    test(
      'yerel takvim günü değişmese de sunucu günü değişince hak açılır',
      () async {
        // Aynı UTC anının iki yüzü: İstanbul günü 2026-11-04, "dünün" kaydı
        // 2026-11-03. Yerel gün kullanılsaydı kayıt bugüne eşit sayılırdı.
        SharedPreferences.setMockInitialValues({});
        var calls = 0;
        Future<int> award() async {
          calls++;
          return 25;
        }

        final yesterday = DateTime.utc(2026, 11, 3, 12);
        final today = DateTime.utc(2026, 11, 4, 12);
        expect(
          await ResultSharer.settleDailyShareRewardAmount(
            awardCoins: award,
            now: yesterday,
          ),
          25,
        );
        expect(
          await ResultSharer.settleDailyShareRewardAmount(
            awardCoins: award,
            now: today,
          ),
          25,
        );
        expect(calls, 2);
      },
    );
  });

  group('eşitleme kuyruğu kendiliğinden yeniden denenir', () {
    test('kuyrukta kayıt varken zamanlayıcı kurulur ve artar', () async {
      SyncManager.retryTimerOverride = true;
      addTearDown(() => SyncManager.retryTimerOverride = null);
      LocalProgressScope.bind('user-b');
      final manager = await SyncManager.initialize(
        _Repo('user-b'),
        connectivityMonitor: _Online(),
      );
      await manager.queueCoinSpend(
        amount: 20,
        reason: 'wildcard',
        idempotencyKey: 'retry-1',
      );
      await manager.sync();
      expect(manager.pendingCount, 1);
      expect(manager.scheduledRetryDelay, isNotNull);
      expect(
        manager.scheduledRetryDelay! >= const Duration(seconds: 30),
        isTrue,
      );
      manager.dispose();
      expect(manager.scheduledRetryDelay, isNull);
    });
  });
}
