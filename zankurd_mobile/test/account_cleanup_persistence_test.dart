import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

/// Başarılı bellek temizliği disk temizliği değildir. Eski testler yalnız
/// başarılı platform yazımları kullandığı için false/exception sonrası yeni
/// hesap sahipliğinin kaydedilmesini ve eski verinin yeniden gelmesini kaçırdı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ownerKey = 'flutter.zankurd.localProgress.deviceOwnerUserId';
  const nextUser = User(
    id: 'new-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-09-21T00:00:00Z',
  );
  final cases = <String, Object>{
    'zankurd.xp.total': 500,
    'zankurd.streak.best': 8,
    'zankurd.achievements.answeredQuestions': 20,
    'zankurd.badges.unlocked': <String>['perfect_game'],
    'zankurd.mastery.Ziman': 4,
    'zankurd.missions.answeredToday': 5,
    'zankurd.placement.v1.skipped': true,
    'zankurd.story.first': 'node-2',
    'zankurd.level.played': <String>['Ziman|-|1'],
    'zankurd.learning_goal.v1': 'learn_kurmanci',
  };

  void resetStores() {
    XPStore.resetInstance();
    StreakStore.resetInstance();
    AchievementStore.resetInstance();
    BadgeService.resetInstance();
    MasteryStore.resetInstance();
    DailyMissionStore.resetInstance();
    PlacementStore.resetInstance();
    StoryProgressStore.resetInstance();
    LevelProgressStore.resetInstance();
    LearningGoalStore.resetInstance();
    MistakeStore.resetInstance();
    SeenQuestionStore.resetInstance();
    QuizResultProgressReceiptStore.debugResetInFlight();
  }

  setUp(() {
    LocalProgressScope.debugReset();
    resetStores();
  });
  tearDown(() {
    resetStores();
    SharedPreferences.setMockInitialValues({});
  });

  for (final throwsError in [false, true]) {
    for (final entry in cases.entries) {
      test(
        '${entry.key}: cleanup failure ($throwsError) blocks owner and retries',
        () async {
          final key = 'flutter.${entry.key}';
          final disk = _FailingPreferences(
            {ownerKey: 'old-user', key: entry.value},
            key,
            throwsError,
          );
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = disk;
          final provider = AuthProvider.test();
          addTearDown(provider.dispose);

          expect(
            await provider.debugResetLocalProgressIfForeignUser(nextUser),
            isFalse,
          );
          expect(disk.values[ownerKey], 'old-user');
          expect(disk.values[key], entry.value);

          disk.fail = false;
          expect(
            await provider.debugResetLocalProgressIfForeignUser(nextUser),
            isTrue,
          );
          expect(disk.values.containsKey(key), isFalse);
          expect(
            disk.values['flutter.zankurd.scope.old-user.${entry.key}'],
            entry.value,
            reason: 'genel anahtar eski sahibin alanına taşınmalı',
          );
          expect(disk.values[ownerKey], 'new-user');
        },
      );
    }
  }

  test('quiz receipt stays with its user across account switch', () async {
    const receiptKey =
        'flutter.zankurd.quiz_result_progress_receipt.old-user:room';
    final disk = _FailingPreferences(
      {ownerKey: 'old-user', receiptKey: '{}'},
      '',
      false,
    );
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = disk;
    final provider = AuthProvider.test();
    addTearDown(provider.dispose);

    expect(
      await provider.debugResetLocalProgressIfForeignUser(nextUser),
      isTrue,
    );
    expect(disk.values.containsKey(receiptKey), isTrue);
    expect(disk.values[ownerKey], 'new-user');
  });

  test(
    'owner write failure is not reported as a completed account switch',
    () async {
      final disk = _FailingPreferences({ownerKey: 'old-user'}, '', false)
        ..failOwnerWrite = true;
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = disk;
      final provider = AuthProvider.test();
      addTearDown(provider.dispose);

      expect(
        await provider.debugResetLocalProgressIfForeignUser(nextUser),
        isFalse,
      );
      expect(disk.values[ownerKey], 'old-user');
      disk.failOwnerWrite = false;
      expect(
        await provider.debugResetLocalProgressIfForeignUser(nextUser),
        isTrue,
      );
      expect(disk.values[ownerKey], 'new-user');
    },
  );

  test('rapid A→B session preparation leaves only B scope active', () async {
    const userA = User(
      id: 'user-a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-09-25T00:00:00Z',
    );
    const userB = User(
      id: 'user-b',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-09-25T00:00:00Z',
    );
    final started = Completer<void>();
    final allow = Completer<void>();
    final disk = _FailingPreferences({ownerKey: 'old-user'}, '', false)
      ..delayedOwnerValue = 'user-a'
      ..ownerWriteStarted = started
      ..allowOwnerWrite = allow;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = disk;
    final provider = AuthProvider.test();
    addTearDown(provider.dispose);

    final first = provider.debugPrepareSessionUser(userA, restartSync: false);
    await started.future;
    final second = provider.debugPrepareSessionUser(userB, restartSync: false);
    allow.complete();
    await Future.wait([first, second]);

    expect(disk.values[ownerKey], 'user-b');
    expect(LocalProgressScope.activeUserId, 'user-b');
  });
}

class _FailingPreferences extends SharedPreferencesStorePlatform {
  _FailingPreferences(this.values, this.failingKey, this.throwsError);
  final Map<String, Object> values;
  final String failingKey;
  final bool throwsError;
  bool fail = true;
  bool failOwnerWrite = false;
  String? delayedOwnerValue;
  Completer<void>? ownerWriteStarted;
  Completer<void>? allowOwnerWrite;

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('.deviceOwnerUserId') && value == delayedOwnerValue) {
      if (ownerWriteStarted != null && !ownerWriteStarted!.isCompleted) {
        ownerWriteStarted!.complete();
      }
      await allowOwnerWrite?.future;
    }
    if (failOwnerWrite && key.endsWith('.deviceOwnerUserId')) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (fail && key == failingKey) {
      if (throwsError) throw PlatformException(code: 'injected_remove_failure');
      return false;
    }
    values.remove(key);
    return true;
  }
}
