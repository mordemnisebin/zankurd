/// Son sürüm incelemesi (r13): hesap silmede yeni yerel anahtarlar ve seri
/// onarımı niyetinin sonsuz yeniden denenmesi.
///
/// ## Kusurlar
///
/// 1. Hesap silme `clearUserOwnedKeys` önek listesiyle temizler; gece eklenen
///    `zankurd.pendingOp.<tür>.<uid>` (kimlik SONDA), `zankurd.quarantine.
///    zankurd.scope.<uid>....` ve yaş beyanı sahip anahtarı listede yoktu: silinen
///    hesabın işlem niyetleri, karantinadaki günlük girdileri ve "13+" beyanı
///    cihazda kalıyordu.
/// 2. `StreakRepairService.recoverPending` niyeti yalnız `failed` dışında
///    siliyordu; sunucu "pencere kapandı" (`break day out of range`) dediğinde
///    sonuç `failed`e düşüyor ve niyet her açılışta sonsuza dek yeniden deneniyordu.
///
/// ## Niçin sessiz kalırdı
///
/// İkisi de hata üretmez: artık anahtar görünmez, sunucu reddi sessizce yutulur.
/// Mevcut anahtar testleri yalnız bilinen önekleri, onarım testleri yalnız
/// başarı/yetersiz bakiye yolunu sınıyordu.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/age_gate_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/streak_repair_service.dart';

class _Depo extends MockZanKurdRepository {
  _Depo(this.sonuc);
  StreakRepairOutcome sonuc;
  @override
  Future<StreakRepairResult> spendStreakRepair({
    required String monthKey,
    required String breakDay,
    required bool premium,
  }) async => StreakRepairResult(sonuc);
}

String _gun(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  test(
    'hesap silme: pendingOp, karantina ve yaş beyanı sahibi temizlenir',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.pendingOp.streak_repair.user-a': '{}',
        'zankurd.pendingOp.spin.user-a': '{}',
        'zankurd.pendingOp.spin.user-b': '{}',
        'zankurd.quarantine.zankurd.scope.user-a.zankurd.xp.resultJournal.op1':
            'x',
        'zankurd.quarantine.zankurd.scope.user-b.zankurd.xp.resultJournal.op1':
            'x',
        AgeGate.declarationKey: 'adult',
        AgeGate.askedKey: true,
        AgeGate.ownerKey: 'user-a',
      });
      final prefs = await SharedPreferences.getInstance();
      await LocalProgressScope.clearUserOwnedKeys(prefs, 'user-a');
      await AgeGate.forgetUser('user-a');
      expect(prefs.getKeys().where((k) => k.contains('user-a')), isEmpty);
      expect(prefs.getString(AgeGate.declarationKey), isNull);
      expect(prefs.getBool(AgeGate.askedKey), isNull);
      // Başka hesaba dokunulmaz.
      expect(prefs.getKeys(), contains('zankurd.pendingOp.spin.user-b'));
      expect(
        prefs.getKeys(),
        contains(
          'zankurd.quarantine.zankurd.scope.user-b.zankurd.xp.resultJournal.op1',
        ),
      );
    },
  );

  test(
    'yaş beyanı: silinen hesap başkasınınkini ve çocuk beyanını bozmaz',
    () async {
      SharedPreferences.setMockInitialValues({
        AgeGate.declarationKey: 'adult',
        AgeGate.ownerKey: 'user-b',
      });
      await AgeGate.forgetUser('user-a');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AgeGate.declarationKey), 'adult');
    },
  );

  test('silme zinciri yaş beyanını da temizler (kaynak bekçisi)', () {
    final auth = File(
      'lib/src/providers/auth_provider.dart',
    ).readAsStringSync();
    expect(auth, contains('AgeGate.forgetUser(deletedId)'));
  });

  test('seri onarımı: sunucu "pencere kapandı" derse niyet silinir', () async {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month, now.day - 2);
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': 6,
      'zankurd.streak.best': 6,
      'zankurd.streak.lastDay': _gun(lastDay),
    });
    StreakStore.resetInstance();
    final store = await StreakStore.load();
    final offer = store.repairOffer()!;
    final prefs = await SharedPreferences.getInstance();
    const key = 'zankurd.pendingOp.streak_repair.user';

    // Belirsiz sonuç niyeti bırakır.
    await StreakRepairService.repair(
      repository: _Depo(StreakRepairOutcome.failed),
      store: store,
      offer: offer,
    );
    expect(prefs.getString(key), isNotNull);

    // Pencere kapandı = kesin sonuç: niyet silinir, açılışta tekrar denenmez.
    await StreakRepairService.recoverPending(
      repository: _Depo(StreakRepairOutcome.windowClosed),
      store: store,
    );
    expect(prefs.getString(key), isNull);
  });

  test('Supabase eşlemesi pencere hatalarını windowClosed yapar', () {
    final src = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(src, contains("'break day out of range' ||"));
    expect(src, contains('StreakRepairOutcome.windowClosed'));
  });
}
