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

/// "Yanlışları tekrar et" alıştırması her turda +50 taban XP, ustalık
/// sayacı (+200 terfi) ve görev ilerlemesi veriyordu; aynı yanlışları
/// sonsuz tekrar ederek XP kasılıyordu. Süre dolarak geçen solo tur da
/// sıfır doğruyla +50 alıyordu (2026-10-25).
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

  AnswerRecord record(int i, {String selected = 'A'}) => AnswerRecord(
    id: 'q$i',
    category: 'Ziman',
    prompt: 'p$i',
    answers: const ['A', 'B'],
    correctAnswer: 'A',
    selectedAnswer: selected,
    explanation: '',
    responseMs: 4000,
  );

  Future<void> playRound(
    WidgetTester tester, {
    required List<AnswerRecord> records,
    required bool practice,
  }) async {
    final correct = records.where((r) => r.isCorrect).length;
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: MockZanKurdRepository(),
          room: _room,
          score: 100,
          correctCount: correct,
          wrongCount: records.length - correct,
          totalQuestions: records.length,
          bestStreak: 1,
          answerRecords: records,
          coinsAwarded: 0,
          practice: practice,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('alıştırma yalnız doğru başına küçük XP verir, ustalık yok', (
    tester,
  ) async {
    await playRound(
      tester,
      records: [for (var i = 1; i <= 4; i++) record(i)],
      practice: true,
    );

    expect((await XPStore.load()).totalXP, 20);
    expect((await MasteryStore.load()).correctCount('Ziman'), 0);
  });

  testWidgets('sıfır doğrulu solo tur taban bonus almaz', (tester) async {
    await playRound(
      tester,
      records: [for (var i = 1; i <= 4; i++) record(i, selected: 'B')],
      practice: false,
    );

    // Yalnız günün ilk turu bonusu (+30) kalabilir; +50 taban yok.
    expect((await XPStore.load()).totalXP, lessThanOrEqualTo(30));
  });

  testWidgets('normal solo tur ödülü değişmedi', (tester) async {
    await playRound(
      tester,
      records: [for (var i = 1; i <= 4; i++) record(i)],
      practice: false,
    );

    final xp = (await XPStore.load()).totalXP;
    expect(xp, greaterThanOrEqualTo(4 * 10 + 50));
    expect((await MasteryStore.load()).correctCount('Ziman'), 4);
  });
}
