/// 2.1.2 W3 bekçileri: yazım SONUCU denetimleri ve favori kuyruğu
/// (ChatGPT Pro denetimi alan 3 #2, #9, #10, #22, #23; alan 4 #12).
///
/// Ortak kusur: platform yazımı `false` döndürüyor ama hata fırlatmıyor;
/// kod bayrağı/sayacı bellekte ilerletip "kaydedildi" sanıyordu, yeniden
/// açılışta ilerleme (seri, XP, görev alındı işareti) geri geliyordu. Bellek
/// sahte deposu her yazımı kabul ettiğinden kusur testlerde görünmezdi; yalnız
/// `setValue == false` döndüren bir depo gösterir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

class _FailingStore extends SharedPreferencesStorePlatform {
  _FailingStore(this.values);

  final Map<String, Object> values;
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
    if (failAll) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform original;
  late _FailingStore store;

  setUp(() async {
    original = SharedPreferencesStorePlatform.instance;
    store = _FailingStore({});
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    LocalProgressScope.debugReset();
    LocalProgressScope.bind('user-a');
    StreakStore.resetInstance();
    XPStore.resetInstance();
    MasteryStore.resetInstance();
    DailyMissionStore.resetInstance();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = original;
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });

  group('reddedilen yazım başarı sayılmaz', () {
    test(
      'seri: yazım reddedilirse recordPlay fırlatır, bellek diske döner (#2)',
      () async {
        final streak = await StreakStore.load();
        store.failAll = true;
        await expectLater(
          streak.recordPlay(now: DateTime(2026, 11, 5, 12)),
          throwsStateError,
          reason: 'eskiden yeni seri dönüyor, yeniden açılışta geri düşüyordu',
        );
        expect(
          streak.effectiveStreak(now: DateTime(2026, 11, 5, 12)),
          0,
          reason: 'bellek diskteki gerçeğe dönmeli',
        );
        store.failAll = false;
        expect(await streak.recordPlay(now: DateTime(2026, 11, 5, 12)), 1);
      },
    );

    test(
      'XP: kimliksiz yazım reddedilirse eklenen XP bellekte kalmaz (#22)',
      () async {
        final xp = await XPStore.load();
        store.failAll = true;
        await expectLater(xp.addXP(50), throwsStateError);
        expect(xp.totalXP, 0);
        store.failAll = false;
        await xp.addXP(50);
        expect(xp.totalXP, 50);
      },
    );

    test(
      'ustalık: kimliksiz doğru sayısı yazımı reddedilirse fırlatır (#22)',
      () async {
        final mastery = await MasteryStore.load();
        store.failAll = true;
        await expectLater(mastery.addCorrect('Tarih', 3), throwsStateError);
      },
    );

    test(
      'günlük görev: "alındı" yazımı reddedilirse false döner (#23)',
      () async {
        final missions = await DailyMissionStore.load();
        final mission = missions.missions.first;
        mission.completed = true;
        var granted = 0;
        store.failAll = true;
        final claimed = await missions.claimRewardAfter(mission, () async {
          granted++;
        });
        expect(claimed, isFalse, reason: 'kaydedilmemiş "alındı" başarı değil');
        expect(mission.claimed, isFalse);
        expect(granted, 1);
      },
    );
  });

  group('bildirime dokunma dinleyicisi (alan 4 #12)', () {
    test(
      'Firebase yokken çağrı sessizce döner ve bayrakları kilitlemez',
      () async {
        PushTapRouter.resetForTest();
        await PushTapRouter.wireFirebase();
        await PushTapRouter.wireFirebase();
        PushTapRouter.resetForTest();
      },
    );
  });

  group('çıkışta FCM jetonu (alan 4 #4)', () {
    test('jeton bilinmiyorsa parametresiz KOŞULSUZ temizlik çağrılmaz', () {
      final source = File(
        'lib/src/providers/auth_provider.dart',
      ).readAsStringSync();
      // Koşulsuz çağrı yalnız `isMissingRpcError` yedeğinde kalabilir; "jeton
      // null" dalında (eski else) olmamalı.
      final bare = RegExp(
        r"\.rpc<void>\('clear_my_fcm_token'\)",
      ).allMatches(source).toList();
      expect(bare, hasLength(1), reason: 'yalnız PGRST202 yedeği kalmalı');
      final fallbackStart = source.indexOf(
        'if (!isMissingRpcError(error)) rethrow;',
      );
      expect(fallbackStart, isNonNegative);
      expect(bare.single.start, greaterThan(fallbackStart));
    });
  });
}
