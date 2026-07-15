import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DailyMissionStore.resetInstance();
  });

  test('load returns 3 missions', () async {
    final store = await DailyMissionStore.load();
    expect(store.missions.length, 3);
  });

  test('same day yields identical mission types', () async {
    final store1 = await DailyMissionStore.load();
    final types1 = store1.missions.map((m) => m.type).toList();
    DailyMissionStore.resetInstance();
    final store2 = await DailyMissionStore.load();
    final types2 = store2.missions.map((m) => m.type).toList();
    expect(types1, equals(types2));
  });

  test('reportQuizCompleted increments answerCorrect progress', () async {
    final missions = [
      DailyMission(type: MissionType.answerCorrect, target: 10, coinReward: 50),
      DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
      DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    await store.reportQuizCompleted(
      correctAnswers: 4,
      category: 'Ziman',
      streakAlive: false,
    );
    expect(missions[0].progress, 4);
  });

  test('reportQuizCompleted completes quiz mission immediately', () async {
    final missions = [
      DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25),
      DailyMission(type: MissionType.answerCorrect, target: 10, coinReward: 50),
      DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    final completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Ziman',
      streakAlive: false,
    );
    expect(missions[0].completed, isTrue);
    expect(completed.length, 1);
    expect(completed.first.type, MissionType.completeQuiz);
  });

  test(
    'reportQuizCompleted completes keepStreak when streak is alive',
    () async {
      final missions = [
        DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
        DailyMission(
          type: MissionType.answerCorrect,
          target: 10,
          coinReward: 50,
        ),
        DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
      ];
      final store = await DailyMissionStore.loadForTest(missions);
      final completed = await store.reportQuizCompleted(
        correctAnswers: 0,
        category: 'Ziman',
        streakAlive: true,
      );
      expect(missions[0].completed, isTrue);
      expect(completed.any((m) => m.type == MissionType.keepStreak), isTrue);
    },
  );

  test('reportWildcardUsed increments and completes at target', () async {
    final missions = [
      DailyMission(type: MissionType.useWildcard, target: 2, coinReward: 40),
      DailyMission(type: MissionType.answerCorrect, target: 5, coinReward: 30),
      DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25),
    ];
    final store = await DailyMissionStore.loadForTest(missions);
    final first = await store.reportWildcardUsed();
    expect(missions[0].progress, 1);
    expect(first, isNull);
    final second = await store.reportWildcardUsed();
    expect(missions[0].progress, 2);
    expect(second, isNotNull);
    expect(second!.type, MissionType.useWildcard);
    expect(missions[0].completed, isTrue);
  });

  test(
    'already completed missions are skipped in subsequent reports',
    () async {
      final missions = [
        DailyMission(
          type: MissionType.completeQuiz,
          target: 1,
          coinReward: 25,
          completed: true,
          progress: 1,
        ),
        DailyMission(
          type: MissionType.answerCorrect,
          target: 5,
          coinReward: 30,
        ),
        DailyMission(type: MissionType.keepStreak, target: 1, coinReward: 30),
      ];
      final store = await DailyMissionStore.loadForTest(missions);
      final completed = await store.reportQuizCompleted(
        correctAnswers: 5,
        category: 'Ziman',
        streakAlive: true,
      );
      expect(completed.any((m) => m.type == MissionType.completeQuiz), isFalse);
    },
  );

  test('stale date resets progress', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zankurd.missions.date', '1999-01-01');
    await prefs.setStringList('zankurd.missions.progress', ['5', '5', '5']);
    await prefs.setStringList('zankurd.missions.completed', [
      'true',
      'true',
      'true',
    ]);
    DailyMissionStore.resetInstance();
    final store = await DailyMissionStore.load();
    expect(
      store.missions.every((m) => m.progress == 0 && !m.completed),
      isTrue,
    );
  });

  test('playCategory mission completes only when category matches', () async {
    final missions = [
      DailyMission(
        type: MissionType.playCategory,
        target: 1,
        coinReward: 25,
        category: 'Ziman',
      ),
      DailyMission(type: MissionType.answerCorrect, target: 5, coinReward: 30),
      DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
    ];
    final store = await DailyMissionStore.loadForTest(missions);

    var completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Muzîk',
      streakAlive: false,
    );
    expect(completed.any((m) => m.type == MissionType.playCategory), isFalse);

    completed = await store.reportQuizCompleted(
      correctAnswers: 0,
      category: 'Ziman',
      streakAlive: false,
    );
    expect(completed.any((m) => m.type == MissionType.playCategory), isTrue);
  });

  test('mission keys use ASCII slugs for every supported category', () {
    expect(
      DailyMission(
        type: MissionType.playCategory,
        target: 1,
        coinReward: 25,
        category: 'Siyaset',
      ).missionKey,
      'playCategory:siyaset',
    );
    expect(
      DailyMission(
        type: MissionType.playCategory,
        target: 1,
        coinReward: 25,
        category: 'Paradigma',
      ).missionKey,
      'playCategory:paradigma',
    );
  });

  test('category slug mapping avoids dart2js string-switch expressions', () {
    final source = File('lib/src/models/daily_mission.dart').readAsStringSync();
    expect(source, contains('static const Map<String, String>'));
    expect(source, isNot(contains('=> switch (category)')));
  });
}
