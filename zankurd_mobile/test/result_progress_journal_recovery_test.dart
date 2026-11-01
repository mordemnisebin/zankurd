import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/result_progress_journal.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void restart(_Disk disk) {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = disk;
    QuizResultProgressReceiptStore.debugResetInFlight();
    AchievementStore.resetInstance();
    MasteryStore.resetInstance();
    DailyMissionStore.resetInstance();
    XPStore.resetInstance();
    LocalProgressScope.debugReset();
  }

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
    MasteryStore.resetInstance();
    DailyMissionStore.resetInstance();
    XPStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  Future<void> applyRound() async {
    final prefs = await SharedPreferences.getInstance();
    await QuizResultProgressReceiptStore(prefs).runOnce(
      userId: 'owner',
      roomId: 'round',
      resumable: true,
      action: () async {
        final achievements = await AchievementStore.load();
        await achievements.recordQuizResult(
          category: 'Ziman',
          totalQuestions: 25,
          correctCount: 20,
          bestStreak: 4,
          dailyStreak: 1,
          userScore: 200,
          operationId: 'round',
        );
        final mastery = await MasteryStore.load();
        final promotion = await mastery.addCorrect(
          'Ziman',
          20,
          operationId: 'round',
        );
        await mastery.recordAnswered(
          'Ziman',
          25,
          correct: 20,
          operationId: 'round',
        );
        final missions = await DailyMissionStore.load();
        await missions.reportQuizCompleted(
          correctAnswers: 20,
          category: 'Ziman',
          streakAlive: true,
          completionId: 'round',
        );
        final xp = await XPStore.load();
        await xp.addXP(
          250 + (promotion == null ? 0 : 200),
          operationId: 'round',
        );
      },
    );
  }

  test(
    'G4 kazanım atlanıyordu; eski test yalnız çift yazımı arıyordu: her kalıcı yazımdaki kesinti eksiksiz kurtarılır',
    () async {
      final baseline = _Disk();
      restart(baseline);
      await applyRound();
      final writeCount = baseline.writes;
      expect(writeCount, greaterThan(20));
      for (var failAt = 1; failAt <= writeCount; failAt++) {
        for (final persistBeforeFailure in [false, true]) {
          final disk = _Disk(
            failAt: failAt,
            persistBeforeFailure: persistBeforeFailure,
          );
          restart(disk);
          await expectLater(
            applyRound(),
            throwsStateError,
            reason: 'write $failAt, persisted=$persistBeforeFailure',
          );
          disk.failAt = null;
          restart(disk); // Bellek yok; yalnız gerçekten yazılmış disk kalır.
          await applyRound();
          restart(disk);
          await applyRound(); // İkinci kurtarma kazanımı tekrar artıramaz.
          expect(
            (await AchievementStore.load()).answeredQuestions,
            25,
            reason: 'write $failAt',
          );
          final mastery = await MasteryStore.load();
          expect(mastery.correctCount('Ziman'), 20, reason: 'write $failAt');
          expect(mastery.answeredCount('Ziman'), 25, reason: 'write $failAt');
          expect(mastery.accuracyPercent('Ziman'), 80, reason: 'write $failAt');
          expect(
            (await DailyMissionStore.load()).correctAnswersToday,
            20,
            reason: 'write $failAt',
          );
          expect((await XPStore.load()).totalXP, 450, reason: 'write $failAt');
          expect(
            (await QuizResultProgressReceiptStore(
              await SharedPreferences.getInstance(),
            ).read(userId: 'owner', roomId: 'round'))!.stage,
            QuizResultReceiptStage.acknowledgementPending,
          );
        }
      }
    },
  );

  test(
    'G4 depo yokken ustalık atlanıyordu; hata yutulduğu için makbuz başarı sayıyordu',
    () async {
      final disk = _Disk()..readFails = true;
      restart(disk);
      final mastery = await MasteryStore.load();
      disk.readFails = false;
      await expectLater(
        mastery.recordAnswered('Ziman', 3, operationId: 'round'),
        throwsStateError,
      );
    },
  );

  test(
    'G4 yarım hedef yeni turu eziyordu; tek tur testleri gizliyordu: yeni işlem önce eski günlüğü tamamlar',
    () async {
      final disk = _Disk(failAt: 3);
      restart(disk);
      final prefs = await SharedPreferences.getInstance();
      Future<Map<String, dynamic>> add(String id) => ResultProgressJournal.run(
        preferences: prefs,
        namespace: 'journal',
        operationId: id,
        prepare: () => ResultProgressMutation(
          values: {'xp': (prefs.getInt('xp') ?? 0) + 10},
        ),
      );
      await expectLater(add('first'), throwsStateError);
      disk.failAt = null;
      await add('second');
      await add('first');
      expect(prefs.getInt('xp'), 20);
    },
  );
}

class _Disk extends SharedPreferencesStorePlatform {
  _Disk({this.failAt, this.persistBeforeFailure = false});
  int? failAt;
  final bool persistBeforeFailure;
  int writes = 0;
  bool readFails = false;
  final Map<String, Object> values = {};

  @override
  Future<Map<String, Object>> getAll() async {
    if (readFails) throw StateError('injected preferences unavailable');
    return Map.of(values);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes++;
    if (writes == failAt) {
      if (persistBeforeFailure) values[key] = value;
      return false;
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}
