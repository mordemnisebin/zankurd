/// Dayanıklı işlem kimlikleri: seri onarımı niyeti, bekleyen işlem kimliği,
/// görev XP'si. (Sunucu yarısı: tool/test_idempotency_tur9_local.mjs.)
///
/// ## Kusur
///
/// Para/ödül yazan çağrıların yeniden denemesi, ilk çağrı sunucuda işlenmiş ama
/// yanıtı kaybolmuşsa YENİ işlem sayılıyordu:
/// * Seri onarımı: tahsilat ile yerel `applyRepair` arasında uygulama kapanır ya
///   da yanıt kaybolursa, teklifin geçerlilik günü geçince yerel ön kontrol
///   sunucuya yeniden başvurmayı engelliyordu; jeton gitmiş, seri onarılmamıştı.
/// * Günlük görev XP'si: `addXP` işlem kimliği olmadan çağrılıyordu; XP yazılıp
///   `claimed` bayrağı kalıcılaşmadan uygulama kapanırsa aynı görev ikinci kez
///   alınabiliyordu.
/// * Çark / düello: kimlik üretilip KALICI yazılmıyor, her deneme yeni işlemdi
///   (bkz. PendingOperationStore).
///
/// ## Niçin sessiz kalırdı
///
/// Her adım kendi başına doğru: tek çağrılı testler geçer, kusur yalnız "çağrı
/// işlendi, yanıt kayboldu, uygulama yeniden açıldı" dizisinde görünür.
///
/// ## Kural
///
/// Kimlik/niyet çağrıdan ÖNCE kalıcı yazılır, yeniden denemede AYNEN kullanılır
/// ve yalnız kesin sonuçta silinir; belirsiz sonuçta kalır.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/pending_operation_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/streak_repair_service.dart';
import 'package:zankurd_mobile/src/utils/client_round_id.dart';

/// Her yazımı reddeden depo (disk dolu / bozuk depo taklidi).
class _FailingStore extends SharedPreferencesStorePlatform {
  @override
  Future<Map<String, Object>> getAll() async => {};

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> remove(String key) async => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

/// Tahsilat sunucuda işlenir ama yanıt KAYBOLUR (`failed`).
class _LostResponseRepository extends MockZanKurdRepository {
  bool lose = true;
  int calls = 0;

  @override
  Future<StreakRepairResult> spendStreakRepair({
    required String monthKey,
    required String breakDay,
    required bool premium,
  }) async {
    calls++;
    final real = await super.spendStreakRepair(
      monthKey: monthKey,
      breakDay: breakDay,
      premium: premium,
    );
    if (lose) return const StreakRepairResult(StreakRepairOutcome.failed);
    return real;
  }
}

Future<StreakStore> _brokenStore() async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({
    'zankurd.streak.current': 6,
    'zankurd.streak.best': 6,
    'zankurd.streak.lastDay': '2026-10-22',
  });
  StreakStore.resetInstance();
  return StreakStore.load();
}

void main() {
  final today = DateTime(2026, 10, 24, 9);

  group('PendingOperationStore', () {
    setUp(() {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
    });

    test('kimlik kalıcıdır ve yeniden denemede AYNEN döner', () async {
      final a = await PendingOperationStore.idFor('spin', 'u1');
      final b = await PendingOperationStore.idFor('spin', 'u1');
      expect(a, b);
      expect(isClientRoundId(a), isTrue);
      // "Uygulama yeniden açıldı": bellekteki her şey gitti, kayıt duruyor.
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zankurd.pendingOp.spin.u1'), contains(a));
    });

    test('kesin yanıttan sonra yeni kimlik üretilir', () async {
      final a = await PendingOperationStore.idFor('spin', 'u1');
      await PendingOperationStore.clear('spin', 'u1');
      expect(await PendingOperationStore.idFor('spin', 'u1'), isNot(a));
    });

    test('kapsam ve hesap ayrıdır; kapsam değişince yeni kimlik', () async {
      final a = await PendingOperationStore.idFor('duel', 'u1', scope: 'x');
      expect(
        await PendingOperationStore.idFor('duel', 'u2', scope: 'x'),
        isNot(a),
      );
      expect(
        await PendingOperationStore.idFor('duel', 'u1', scope: 'y'),
        isNot(a),
      );
    });

    test('süresi dolan kimlik canlandırılmaz', () async {
      final t0 = DateTime(2026, 11, 7, 9);
      final a = await PendingOperationStore.idFor(
        'duel',
        'u1',
        maxAge: const Duration(minutes: 10),
        now: t0,
      );
      expect(
        await PendingOperationStore.idFor(
          'duel',
          'u1',
          maxAge: const Duration(minutes: 10),
          now: t0.add(const Duration(minutes: 9)),
        ),
        a,
      );
      expect(
        await PendingOperationStore.idFor(
          'duel',
          'u1',
          maxAge: const Duration(minutes: 10),
          now: t0.add(const Duration(minutes: 11)),
        ),
        isNot(a),
      );
    });

    test('bozuk kayıt yenisiyle değiştirilir, hata fırlatmaz', () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.pendingOp.spin.u1': '{bozuk',
      });
      expect(
        isClientRoundId(await PendingOperationStore.idFor('spin', 'u1')),
        isTrue,
      );
    });
  });

  group('kalıcılık doğrulaması (yan etkili RPC kimliksiz ÇAĞRILMAZ)', () {
    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
    });

    test('eşzamanlı ilk çağrılar TEK kimlik üretir', () async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      final ids = await Future.wait([
        for (var i = 0; i < 8; i++) PendingOperationStore.idFor('spin', 'u1'),
      ]);
      expect(ids.toSet().length, 1);
      expect(await PendingOperationStore.idFor('spin', 'u1'), ids.first);
    });

    test('kimlik yazılamazsa StateError fırlar (RPC çağrılamaz)', () async {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _FailingStore();
      await expectLater(
        PendingOperationStore.idFor('spin', 'u1'),
        throwsStateError,
      );
    });

    test('niyet yazılamazsa ücretli onarım RPC\'si BAŞLAMAZ', () async {
      final store = await _brokenStore();
      final repo = _LostResponseRepository();
      await repo.claimMissionReward(missionKey: 'k', fallbackReward: 250);
      final offer = store.repairOffer(now: today)!;
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _FailingStore();
      final outcome = await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );
      expect(outcome, StreakRepairOutcome.failed);
      expect(repo.calls, 0, reason: 'sunucuya HİÇ gidilmedi');
      expect(await repo.loadCoinBalance(), 250);
    });
  });

  group('seri onarımı: kalıcı niyet', () {
    test('yanıt kaybolur, gün geçer, açılışta onarım TAMAMLANIR '
        've jeton yeniden kesilmez', () async {
      final store = await _brokenStore();
      final repo = _LostResponseRepository();
      await repo.claimMissionReward(missionKey: 'k', fallbackReward: 250);
      final offer = store.repairOffer(now: today)!;

      final outcome = await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );
      expect(outcome, StreakRepairOutcome.failed, reason: 'yanıt kayboldu');
      expect(await repo.loadCoinBalance(), 150, reason: 'sunucu tahsil etti');
      expect(store.effectiveStreak(now: today), 0, reason: 'yerel değişmedi');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('zankurd.pendingOp.streak_repair.user'),
        isNotNull,
        reason: 'niyet belirsiz sonuçta KALIR',
      );

      // Uygulama yeniden açıldı (ertesi gün); ağ geldi.
      repo.lose = false;
      final next = today.add(const Duration(days: 1));
      final applied = await StreakRepairService.recoverPending(
        repository: repo,
        store: store,
        now: next,
      );
      expect(applied, isTrue);
      expect(await repo.loadCoinBalance(), 150, reason: 'ikinci ücret YOK');
      expect(store.effectiveStreak(now: today), 6);
      expect(
        prefs.getString('zankurd.pendingOp.streak_repair.user'),
        isNull,
        reason: 'kesin sonuçta niyet silinir',
      );
      // İkinci açılış: yapılacak iş yok, sunucuya gidilmez.
      final calls = repo.calls;
      expect(
        await StreakRepairService.recoverPending(
          repository: repo,
          store: store,
          now: next,
        ),
        isFalse,
      );
      expect(repo.calls, calls);
    });

    test('kesin ret niyeti siler (yetersiz bakiye)', () async {
      final store = await _brokenStore();
      final repo = MockZanKurdRepository();
      final offer = store.repairOffer(now: today)!;
      final outcome = await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );
      expect(outcome, StreakRepairOutcome.insufficient);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zankurd.pendingOp.streak_repair.user'), isNull);
    });

    test('48 saatten eski niyet sunucuya gitmeden bırakılır', () async {
      final store = await _brokenStore();
      final repo = _LostResponseRepository();
      await repo.claimMissionReward(missionKey: 'k', fallbackReward: 250);
      await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: store.repairOffer(now: today)!,
        now: today,
      );
      repo.lose = false;
      final calls = repo.calls;
      final applied = await StreakRepairService.recoverPending(
        repository: repo,
        store: store,
        now: today.add(const Duration(days: 3)),
      );
      expect(applied, isFalse);
      expect(repo.calls, calls);
    });

    test('niyetten sonra BUGÜN oynandıysa onarım oynanan günü korur', () async {
      final store = await _brokenStore();
      final repo = _LostResponseRepository();
      await repo.claimMissionReward(missionKey: 'k', fallbackReward: 250);
      await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: store.repairOffer(now: today)!,
        now: today,
      );
      repo.lose = false;
      // Kullanıcı bugün oynadı (seri 1'e düştü, kayıp değer saklandı).
      await store.recordPlay(now: today);
      final applied = await StreakRepairService.recoverPending(
        repository: repo,
        store: store,
        now: today,
      );
      expect(applied, isTrue);
      expect(await repo.loadCoinBalance(), 150, reason: 'ikinci ücret YOK');
      // 6 kayıp + bugünkü oyun: niyet anındaki (oynanmamış) teklif değil,
      // güncel yerel durumdan türetilen teklif uygulanır.
      expect(store.effectiveStreak(now: today), 7);
    });

    test('teklif artık geçersizse (hak işlendi) sunucuya gidilmez', () async {
      final store = await _brokenStore();
      final repo = _LostResponseRepository();
      await repo.claimMissionReward(missionKey: 'k', fallbackReward: 250);
      final offer = store.repairOffer(now: today)!;
      await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );
      repo.lose = false;
      await store.applyRepair(offer, now: today); // örn. başka yoldan uygulandı
      final calls = repo.calls;
      expect(
        await StreakRepairService.recoverPending(
          repository: repo,
          store: store,
          now: today,
        ),
        isFalse,
      );
      expect(repo.calls, calls);
    });
  });

  group('görev XP işlem kimliği', () {
    setUp(() {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      DailyMissionStore.resetInstance();
      XPStore.resetInstance();
    });

    test('aynı kimlikle ikinci addXP (uygulama kapanıp yeniden açıldı) '
        'XP eklemez', () async {
      final missions = await DailyMissionStore.load();
      final mission = missions.missions.first;
      final id = missions.claimOperationId(mission);
      expect(id, startsWith('mission_xp:'));

      var xp = await XPStore.load();
      await xp.addXP(100, operationId: id);
      final after = xp.totalXP;
      // Çökme: claimed bayrağı yazılmadı, süreç yeniden başladı.
      XPStore.resetInstance();
      xp = await XPStore.load();
      await xp.addXP(100, operationId: id);
      expect(xp.totalXP, after);
    });

    test('kimlik gün + görev kimliğini taşır', () async {
      final missions = await DailyMissionStore.load();
      final ids = {
        for (final m in missions.missions) missions.claimOperationId(m),
      };
      expect(ids.length, missions.missions.length);
    });
  });
}
