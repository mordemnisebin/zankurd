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
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

const _room = GameRoom(
  name: '1vs1',
  code: 'ZK-TEST000000',
  category: 'Ziman',
  questionCount: 1,
  status: RoomStatus.finished,
  players: [],
);

/// `BadgeService`in beş rozeti hiçbir yerden çağrılmıyordu.
///
/// `evaluateStreakBadges`/`evaluateQuestionBadges`/`evaluatePerfectGame`/
/// `evaluateSpeedDemon` vardı ve kendi başlarına doğru çalışıyordu (bkz.
/// `test/badge_service_test.dart`) ama uygulama kodundan HİÇBİRİ
/// çağrılmıyordu — kullanıcı ne yaparsa yapsın bu beş rozet asla
/// açılamıyordu (2026-08-14 denetimi). `QuizResultScreen._recordProgress`
/// artık tur sonucunun zaten hesapladığı verilerle bunları değerlendirir.
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

  testWidgets('mükemmel bir tur sonunda perfect_game rozeti gerçekten açılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: MockZanKurdRepository(),
          room: _room,
          score: 100,
          correctCount: 3,
          wrongCount: 0,
          totalQuestions: 3,
          bestStreak: 1,
          answerRecords: const [
            AnswerRecord(
              id: 'q1',
              category: 'Ziman',
              prompt: 'p1',
              answers: ['A', 'B'],
              correctAnswer: 'A',
              selectedAnswer: 'A',
              explanation: '',
              responseMs: 4000,
            ),
            AnswerRecord(
              id: 'q2',
              category: 'Ziman',
              prompt: 'p2',
              answers: ['A', 'B'],
              correctAnswer: 'A',
              selectedAnswer: 'A',
              explanation: '',
              responseMs: 4000,
            ),
            AnswerRecord(
              id: 'q3',
              category: 'Ziman',
              prompt: 'p3',
              answers: ['A', 'B'],
              correctAnswer: 'A',
              selectedAnswer: 'A',
              explanation: '',
              responseMs: 4000,
            ),
          ],
          coinsAwarded: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badgeService = await BadgeService.load();
    expect(
      badgeService.isUnlocked('perfect_game'),
      isTrue,
      reason:
          '3/3 doğru cevaplı bir tur bitti ama perfect_game rozeti hâlâ '
          'kapalıysa BadgeService hiç çağrılmıyor demektir',
    );
    // Toplam yanıt süresi 12sn (< 60sn) — hız canavarı da açılmalı.
    expect(badgeService.isUnlocked('speed_demon'), isTrue);
  });

  testWidgets(
    'yavaş biten tur speed_demon açmaz ama perfect_game yine açılır',
    (tester) async {
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: MockZanKurdRepository(),
            room: _room,
            score: 100,
            correctCount: 1,
            wrongCount: 0,
            totalQuestions: 1,
            bestStreak: 1,
            answerRecords: const [
              AnswerRecord(
                id: 'q1',
                category: 'Ziman',
                prompt: 'p1',
                answers: ['A', 'B'],
                correctAnswer: 'A',
                selectedAnswer: 'A',
                explanation: '',
                responseMs: 90000,
              ),
            ],
            coinsAwarded: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgeService = await BadgeService.load();
      expect(badgeService.isUnlocked('perfect_game'), isTrue);
      expect(badgeService.isUnlocked('speed_demon'), isFalse);
    },
  );
}
