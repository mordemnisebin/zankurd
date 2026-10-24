import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/analytics_service.dart';

import 'support/widget_test_helpers.dart';

class _PayloadRepository extends MockZanKurdRepository {
  final completed = <Map<String, dynamic>?>[];

  @override
  Future<bool> logAnalyticsEvent(
    String eventName,
    Map<String, dynamic>? params,
  ) async {
    if (eventName == 'quiz_complete') completed.add(params);
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
    BadgeService.resetInstance();
    DailyMissionStore.resetInstance();
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    StreakStore.resetInstance();
    XPStore.resetInstance();
  });
  tearDown(() => AnalyticsService.instance.debugEventSink = null);

  for (final mode in [
    'learning',
    'practice',
    'crowd',
    '1v1',
    'daily',
    'bot_race',
    'solo',
  ]) {
    testWidgets('quiz_complete $mode payload reaches both analytics paths', (
      tester,
    ) async {
      final repository = _PayloadRepository();
      final firebase = <Map<String, Object>?>[];
      AnalyticsService.instance.debugEventSink = (name, parameters) {
        if (name == 'quiz_complete') firebase.add(parameters);
      };
      final online = mode == 'crowd' || mode == '1v1';
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repository,
            room: GameRoom(
              id: online ? 'test-room' : null,
              name: 'Test',
              code: 'PRIVATE',
              category: 'Ziman',
              players: const [],
              status: RoomStatus.finished,
              isCustom: mode == 'crowd',
              maxPlayers: mode == 'crowd' ? 4 : 2,
            ),
            score: 60,
            correctCount: 1,
            wrongCount: 0,
            totalQuestions: 1,
            bestStreak: 1,
            answerRecords: const [],
            coinsAwarded: 0,
            isLearningExperience: mode == 'learning',
            practice: mode == 'practice' || mode == 'learning',
            dailyQuiz: mode == 'daily',
            opponents: mode == 'bot_race'
                ? const [Player(name: 'Bot', score: 0, state: 'Bot')]
                : const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(firebase, hasLength(1));
      expect(repository.completed, hasLength(1));
      expect(firebase.single, {
        'category': 'Ziman',
        'mode': mode,
        'correct': 1,
        'total': 1,
        'xp': isA<int>(),
      });
      expect(repository.completed.single, {
        'category': 'Ziman',
        'mode': mode,
        'correct_count': 1,
        'total_questions': 1,
        'score': 60,
      });
    });
  }
}
