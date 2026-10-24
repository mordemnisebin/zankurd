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

  AnswerRecord record(int i, {String? selected = 'A', int ms = 4000}) =>
      AnswerRecord(
        id: 'q$i',
        category: 'Ziman',
        prompt: 'p$i',
        answers: const ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: selected,
        explanation: '',
        responseMs: ms,
      );

  Future<BadgeService> playRound(
    WidgetTester tester, {
    required List<AnswerRecord> records,
    bool practice = false,
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
          coinsAwarded: 30,
          practice: practice,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return BadgeService.load();
  }

  testWidgets('mükemmel 5 soruluk tur perfect_game ve speed_demon açar', (
    tester,
  ) async {
    final badges = await playRound(
      tester,
      records: [for (var i = 1; i <= 5; i++) record(i)],
    );
    expect(
      badges.isUnlocked('perfect_game'),
      isTrue,
      reason:
          '5/5 doğru normal tur bitti ama perfect_game kapalıysa '
          'BadgeService hiç çağrılmıyor demektir',
    );
    // Toplam yanıt süresi 20 sn (< 60 sn).
    expect(badges.isUnlocked('speed_demon'), isTrue);
  });

  testWidgets('yavaş biten tur speed_demon açmaz ama perfect_game açılır', (
    tester,
  ) async {
    final badges = await playRound(
      tester,
      records: [for (var i = 1; i <= 5; i++) record(i, ms: 30000)],
    );
    expect(badges.isUnlocked('perfect_game'), isTrue);
    expect(badges.isUnlocked('speed_demon'), isFalse);
  });

  // Kusur: iki rozet her turda değerlendiriliyordu. Tek soruluk turda
  // "hepsi doğru" ve "60 sn'den kısa" kendiliğinden sağlanır; ilk turda iki
  // rozet bedavaya açılıyor, rozet değersizleşiyordu. Sessizdi: açılması
  // hata üretmez.
  testWidgets('5 sorudan kısa tur beceri rozeti açmaz', (tester) async {
    final badges = await playRound(
      tester,
      records: [for (var i = 1; i <= 4; i++) record(i)],
    );
    expect(badges.isUnlocked('perfect_game'), isFalse);
    expect(badges.isUnlocked('speed_demon'), isFalse);
  });

  testWidgets('alıştırma (yanlış tekrarı) turu beceri rozeti açmaz', (
    tester,
  ) async {
    final badges = await playRound(
      tester,
      records: [for (var i = 1; i <= 8; i++) record(i)],
      practice: true,
    );
    expect(badges.isUnlocked('perfect_game'), isFalse);
    expect(badges.isUnlocked('speed_demon'), isFalse);
  });

  // Süresi dolan soru cevap süresine 0 katar: hiç cevaplamamak turu "hızlı"
  // yapıyordu.
  testWidgets('süre aşımı olan tur speed_demon açmaz', (tester) async {
    final badges = await playRound(
      tester,
      records: [
        for (var i = 1; i <= 4; i++) record(i),
        record(5, selected: null, ms: 0),
      ],
    );
    expect(badges.isUnlocked('speed_demon'), isFalse);
    expect(badges.isUnlocked('perfect_game'), isFalse);
  });

  test('isSkillRound kuralı', () {
    bool r(bool practice, int total, int unanswered) =>
        BadgeService.isSkillRound(
          practice: practice,
          totalQuestions: total,
          unanswered: unanswered,
        );
    expect(r(false, 5, 0), isTrue);
    expect(r(false, 10, 0), isTrue);
    expect(r(false, 4, 0), isFalse);
    expect(r(true, 10, 0), isFalse);
    expect(r(false, 10, 1), isFalse);
  });

  // Alıştırma turu seriyi uzatmaz ve dondurma teklifi açmaz: kullanıcı günde
  // yalnız kendi yanlışlarını gözden geçirerek seri biriktiremez.
  testWidgets('alıştırma turu seriyi kaydetmez', (tester) async {
    await playRound(
      tester,
      records: [for (var i = 1; i <= 5; i++) record(i)],
      practice: true,
    );
    final streak = await StreakStore.load();
    expect(streak.lastDay, isNull);
    expect(streak.effectiveStreak(), 0);
  });

  testWidgets('normal tur seriyi kaydeder', (tester) async {
    await playRound(tester, records: [for (var i = 1; i <= 5; i++) record(i)]);
    final streak = await StreakStore.load();
    expect(streak.effectiveStreak(), 1);
  });
}
