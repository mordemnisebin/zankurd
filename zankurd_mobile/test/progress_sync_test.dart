/// Kayıtlı hesabın ilerleme eşitlemesi ([ProgressSyncService]) ve yerel
/// anahtar eşlemesi ([LocalProgressSnapshot]).
///
/// Kusur: kayıtlı kullanıcı çıkışta, telefon değişiminde ve yeniden kurulumda
/// seri/rozet/seviye/tekrar geçmişini kaybediyordu (hepsi yalnız cihazdaydı).
///
/// Niçin sessizdi: yerel mağazalar kendi anahtarlarıyla çalıştığı için hiçbir
/// ekran ya da test "başka cihazda aynı ilerleme var mı" diye sormuyordu.
/// Yeni eşitleme anahtar adlarını mağazalardan BAĞIMSIZ yazdığı için, mağaza
/// anahtarı değişirse sessizce boş okurdu; ilk grup bunu gerçek mağazalarla
/// sabitler.
library;

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';

class _FakeRemote implements ProgressRemote {
  _FakeRemote({this.row});

  RemoteProgress? row;
  Object? fetchError;
  Object? saveError;
  int fetches = 0;
  int saves = 0;
  Map<String, dynamic>? lastSaved;

  @override
  Future<RemoteProgress?> fetch() async {
    fetches++;
    final error = fetchError;
    if (error != null) throw error;
    return row;
  }

  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    saves++;
    final error = saveError;
    if (error != null) throw error;
    lastSaved = snapshot;
    row = RemoteProgress(snapshot: snapshot);
  }
}

void _resetStores() {
  XPStore.resetInstance();
  StreakStore.resetInstance();
  BadgeService.resetInstance();
  AchievementStore.resetInstance();
  LevelProgressStore.resetInstance();
  MasteryStore.resetInstance();
  MistakeStore.resetInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    LocalProgressScope.bind('user-a');
    _resetStores();
  });

  tearDown(ProgressSyncService.unbind);

  group('yerel anahtar eşlemesi gerçek mağazalarla', () {
    test('mağazaların yazdığı değerler anlık görüntüye girer', () async {
      final xp = await XPStore.load();
      await xp.addXP(120);
      final streak = await StreakStore.load();
      await streak.recordPlay(now: DateTime(2026, 10, 14));
      await streak.recordPlay(now: DateTime(2026, 10, 15));
      await streak.addFreeze();
      final badges = await BadgeService.load();
      await badges.evaluatePerfectGame(5, 5);
      final mastery = await MasteryStore.load();
      await mastery.addCorrect('Ziman', 7);
      await mastery.recordAnswered('Ziman', 10, correct: 7);
      final mistakes = await MistakeStore.load();
      await mistakes.markMistake('q-1', category: 'Ziman');
      await (await LevelProgressStore.load()).markPlayed('Ziman', null, 1);

      final prefs = await SharedPreferences.getInstance();
      final snapshot = LocalProgressSnapshot.read(prefs);

      expect(snapshot.xp, 120);
      expect(snapshot.streak.current, 2);
      expect(snapshot.streak.best, 2);
      expect(snapshot.streak.lastDay, '2026-10-15');
      expect(snapshot.streak.freeze, 1);
      expect(snapshot.badges, {'perfect_game'});
      expect(snapshot.mastery['Ziman']!.correct, 7);
      expect(snapshot.mastery['Ziman']!.answered, 10);
      expect(snapshot.mastery['Ziman']!.evidence, 7);
      expect(snapshot.mistakes.ids, {'q-1'});
      expect(snapshot.mistakes.meta['q-1']!['category'], 'Ziman');
      expect(snapshot.mistakes.history.values.single['wrong'], 1);
      expect(snapshot.levelPlayed, {'Ziman|-|1'});
    });

    test('anlık görüntü yazılınca mağazalar aynı değerleri okur', () async {
      final prefs = await SharedPreferences.getInstance();
      const snapshot = ProgressSnapshot(
        xp: 900,
        streak: SnapshotStreak(
          current: 4,
          best: 9,
          lastDay: '2026-10-15',
          freeze: 2,
        ),
        badges: {'streak_30', 'perfect_game'},
        achievements: SnapshotAchievements(
          unlocked: {'first_game'},
          answered: 77,
          categories: {'Ziman'},
          dailyQuiz: 2,
          dailyQuizDay: '2026-10-15',
        ),
        levelPlayed: {'Ziman|-|1', 'Çand|Dîrok|2'},
        mastery: {
          'Ziman': SnapshotMastery(correct: 21, answered: 30, evidence: 25),
        },
        mistakes: SnapshotMistakes(
          ids: {'q-9'},
          meta: {
            'q-9': {
              'nextReview': 1,
              'intervalDays': 1,
              'repetitions': 0,
              'easeFactor': 2.3,
              'category': 'Ziman',
            },
          },
          history: {
            '2026-10-15': {'correct': 3, 'wrong': 2},
          },
        ),
        placementLevel: 'navin',
        story: {'s1': 'n4'},
        learningGoal: 'daily5',
      );

      expect(await LocalProgressSnapshot.write(prefs, snapshot), isTrue);
      _resetStores();

      expect((await XPStore.load()).totalXP, 900);
      final streak = await StreakStore.load();
      expect(streak.best, 9);
      expect(streak.lastDay, '2026-10-15');
      expect(streak.freezeCount, 2);
      expect((await BadgeService.load()).unlockedBadges, {
        'streak_30',
        'perfect_game',
      });
      expect((await AchievementStore.load()).answeredQuestions, 77);
      expect((await MasteryStore.load()).correctCount('Ziman'), 21);
      expect((await MasteryStore.load()).answeredCount('Ziman'), 30);
      final mistakes = await MistakeStore.load();
      expect(mistakes.ids, {'q-9'});
      expect(mistakes.totalCorrect, 3);
      expect(mistakes.totalWrong, 2);
      expect(
        (await LevelProgressStore.load()).isPlayed('Çand', 'Dîrok', 2),
        isTrue,
      );
      // Yazılan ve okunan aynı.
      expect(LocalProgressSnapshot.read(prefs), snapshot);
    });
  });

  group('ProgressSyncService', () {
    Future<ProgressSyncService> bind(
      _FakeRemote remote, {
      void Function()? onLocalChanged,
      Duration debounce = const Duration(milliseconds: 20),
    }) async {
      return ProgressSyncService.bind(
        remote: remote,
        userId: 'user-a',
        preferences: await SharedPreferences.getInstance(),
        onLocalChanged: onLocalChanged,
        debounce: debounce,
      );
    }

    test('yeni cihaz: sunucudaki ilerleme yerele iner', () async {
      final remote = _FakeRemote(
        row: RemoteProgress(
          snapshot: const ProgressSnapshot(
            xp: 400,
            streak: SnapshotStreak(current: 6, best: 6, lastDay: '2026-10-14'),
            badges: {'speed_demon'},
          ).toJson(),
        ),
      );
      var changed = 0;
      final service = await bind(remote, onLocalChanged: () => changed++);

      await service.syncNow();

      final prefs = await SharedPreferences.getInstance();
      final local = LocalProgressSnapshot.read(prefs);
      expect(local.xp, 400);
      expect(local.streak.current, 6);
      expect(local.badges, {'speed_demon'});
      expect(changed, 1);
      // Sunucu zaten aynı: geri yükleme yok.
      expect(remote.saves, 0);
    });

    test('yerel daha ileriyse birleşik hal sunucuya yüklenir', () async {
      final prefs = await SharedPreferences.getInstance();
      await (await BadgeService.load()).evaluatePerfectGame(5, 5);
      await (await XPStore.load()).addXP(50);
      final remote = _FakeRemote(
        row: RemoteProgress(
          snapshot: const ProgressSnapshot(
            xp: 400,
            badges: {'speed_demon'},
          ).toJson(),
        ),
      );
      final service = await bind(remote);

      await service.syncNow();

      final uploaded = ProgressSnapshot.tryParse(remote.lastSaved)!;
      expect(uploaded.xp, 400);
      expect(uploaded.badges, {'perfect_game', 'speed_demon'});
      // Yerel de birleşik hale geldi.
      expect(LocalProgressSnapshot.read(prefs).badges, {
        'perfect_game',
        'speed_demon',
      });
    });

    test(
      'sunucuda kayıt yoksa yerel ilerleme yüklenir; boşsa yüklenmez',
      () async {
        final remote = _FakeRemote();
        final service = await bind(remote);
        await service.syncNow();
        expect(remote.saves, 0, reason: 'boş anlık görüntü yazılmaz');

        await (await XPStore.load()).addXP(10);
        await service.syncNow();
        expect(remote.saves, 1);
        expect(ProgressSnapshot.tryParse(remote.lastSaved)!.xp, 10);

        // Değişmeden ikinci eşitleme yazmaz.
        await service.syncNow();
        expect(remote.saves, 1);
      },
    );

    test(
      'RPC yok (PGRST202): sessizce kapanır, yerel ilerleme bozulmaz',
      () async {
        await (await XPStore.load()).addXP(33);
        final remote = _FakeRemote()
          ..fetchError = const ProgressRemoteMissing();
        final service = await bind(remote);

        await service.syncNow();
        expect(service.isDisabled, isTrue);
        await service.syncNow();
        expect(remote.fetches, 1, reason: 'kapandıktan sonra çağrı yok');
        expect(
          LocalProgressSnapshot.read(await SharedPreferences.getInstance()).xp,
          33,
        );
      },
    );

    test('çevrimdışı (ağ hatası): sessiz, yerel ilerleme korunur', () async {
      await (await XPStore.load()).addXP(21);
      final remote = _FakeRemote()
        ..fetchError = Exception('SocketException: Failed host lookup');
      final service = await bind(remote);

      await expectLater(service.syncNow(), completes);
      expect(service.isDisabled, isFalse, reason: 'ağ gelince yeniden dener');
      expect(
        LocalProgressSnapshot.read(await SharedPreferences.getInstance()).xp,
        21,
      );
    });

    test('daha yeni sürüm anlık görüntü ezilmez ve birleştirilmez', () async {
      await (await XPStore.load()).addXP(5);
      final future = {'v': ProgressSnapshot.currentVersion + 1, 'xp': 9999};
      final remote = _FakeRemote(row: RemoteProgress(snapshot: future));
      final service = await bind(remote);

      await service.syncNow();

      expect(remote.saves, 0);
      expect(
        LocalProgressSnapshot.read(await SharedPreferences.getInstance()).xp,
        5,
      );
    });

    test('kapsam başka kullanıcıya geçtiyse dokunmaz', () async {
      final remote = _FakeRemote(
        row: RemoteProgress(
          snapshot: const ProgressSnapshot(xp: 1000).toJson(),
        ),
      );
      final service = await bind(remote);
      LocalProgressScope.bind('user-b');

      await service.syncNow();

      expect(remote.fetches, 0);
    });

    test(
      'markDirty seyreltilir: art arda çağrılar tek eşitleme yapar',
      () async {
        final remote = _FakeRemote();
        await bind(remote);
        await (await XPStore.load()).addXP(10);

        ProgressSyncService.markDirty();
        ProgressSyncService.markDirty();
        ProgressSyncService.markDirty();
        expect(remote.fetches, 0, reason: 'gecikme dolmadan gitmez');
        // Yüklü makinede zamanlayıcı geç tetiklenebilir: sabit bekleme yerine
        // sonucu bekle.
        for (var i = 0; i < 200 && remote.saves == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }

        expect(remote.fetches, 1);
        expect(remote.saves, 1);
      },
    );

    test(
      'arka plana geçiş: bekleyen değişiklik hemen gider, inactive gitmez',
      () async {
        final remote = _FakeRemote();
        final service = await bind(
          remote,
          debounce: const Duration(minutes: 5),
        );
        await service.syncNow();
        expect(remote.fetches, 1);
        await (await XPStore.load()).addXP(8);
        ProgressSyncService.markDirty();

        // Denetim merkezi/bildirim çekmecesi ağa çıkmaz.
        service.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await pumpEventQueue();
        expect(remote.fetches, 1);

        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        expect(remote.saves, 1);
        expect(ProgressSnapshot.tryParse(remote.lastSaved)!.xp, 8);

        // Bekleyen değişiklik yok ve yeni eşitlendi: arka plan ağa çıkmaz.
        final fetchesBefore = remote.fetches;
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        expect(remote.fetches, fetchesBefore);
      },
    );

    test('flush bekleyen eşitlemeyi hemen yapar (çıkıştan önce)', () async {
      final remote = _FakeRemote();
      final service = await bind(remote, debounce: const Duration(minutes: 5));
      await (await XPStore.load()).addXP(7);
      ProgressSyncService.markDirty();

      await service.flush();

      expect(remote.saves, 1);
    });

    test(
      '240 KB\'ı aşan anlık görüntü geçmişi bırakır, yoksa yüklemez',
      () async {
        final big = SnapshotMistakes(
          ids: {for (var i = 0; i < 10; i++) 'q$i'},
          history: {
            for (var i = 0; i < 12000; i++)
              'gün-${i.toString().padLeft(6, '0')}': {'correct': i, 'wrong': i},
          },
        );
        final prefs = await SharedPreferences.getInstance();
        await LocalProgressSnapshot.write(
          prefs,
          ProgressSnapshot(xp: 1, mistakes: big),
        );
        final remote = _FakeRemote();
        final service = await bind(remote);

        await service.syncNow();

        expect(remote.saves, 1);
        final saved = ProgressSnapshot.tryParse(remote.lastSaved)!;
        expect(saved.mistakes.history, isEmpty);
        expect(saved.mistakes.ids, hasLength(10));
        expect(
          saved.encode().length,
          lessThan(ProgressSnapshot.maxEncodedBytes),
        );
      },
    );
  });
}
