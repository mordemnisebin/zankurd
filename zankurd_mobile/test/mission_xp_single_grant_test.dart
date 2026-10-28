// Bekçi: görev XP'si tek yerden, ödül alınırken verilir (B1).
// 2026-10-29 (X5): sonuç turu artık Günün turu (`dailyQuiz: true`): "yarış
// tamamla" görevi tek başına çözülen solo turda ilerlemez.
//
// ## Kusur
// Günlük görev tamamlanınca XP İKİ kez veriliyordu: sonuç ekranı
// (`QuizResultScreen`) tamamlanan görevlerin `xpReward`ını tur XP'sine
// ekliyor, joker görevi `_trackWildcardMission` aynı ödülü hemen yazıyor;
// sonra ana ekrandaki "Ödülü al" (`_claimMissionReward`) AYNI `xpReward`ı
// bir daha ekliyordu. Her görev 100 yerine 200 XP veriyordu.
//
// ## Niçin sessiz kalırdı
// Her adım kendi başına doğru görünür: sonuç ekranı toplamı gösterir, ana
// ekran "+100 XP alındı" der. Yalnız ikisi birlikte toplanınca fazla çıkar;
// görev testleri deposu ve ekranları ayrı ayrı sınıyordu.
//
// ## Kural
// Görev XP'si yalnız ödül alınırken (ana ekran) verilir. Tur sonucu ve
// joker kullanımı görevi yalnız "tamamlandı" işaretler, XP eklemez.
import 'package:flutter/widgets.dart';
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
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

const _room = GameRoom(
  name: '1vs1',
  code: 'ZK-TEST000001',
  category: 'Ziman',
  questionCount: 1,
  status: RoomStatus.finished,
  players: [],
);

const _record = AnswerRecord(
  id: 'q1',
  category: 'Ziman',
  prompt: 'p1',
  answers: ['A', 'B'],
  correctAnswer: 'A',
  selectedAnswer: 'A',
  explanation: '',
  responseMs: 4000,
);

class _RichRepository extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 500;
}

void _resetStores() {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({});
  AchievementStore.resetInstance();
  BadgeService.resetInstance();
  DailyMissionStore.resetInstance();
  MasteryStore.resetInstance();
  MistakeStore.resetInstance();
  StreakStore.resetInstance();
  XPStore.resetInstance();
}

void main() {
  setUp(_resetStores);

  Future<int> xpAfterResult(WidgetTester tester, List<DailyMission> m) async {
    _resetStores();
    // Aynı türde widget yeniden pompalanırsa State yeniden kurulmaz.
    await tester.pumpWidget(const SizedBox());
    await DailyMissionStore.loadForTest(m);
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
          answerRecords: const [_record],
          coinsAwarded: 10,
          // 2026-10-29 (X5): "yarış tamamla" görevi yalnız yarış turunda
          // ilerler; Günün turu yarış sayılır (tek başına solo tur sayılmaz).
          dailyQuiz: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (await XPStore.load()).totalXP;
  }

  testWidgets('sonuç ekranı tamamlanan görevin XP\'sini TUR XP\'sine eklemez', (
    tester,
  ) async {
    final withoutMission = await xpAfterResult(tester, []);
    final withMission = await xpAfterResult(tester, [
      DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 20),
    ]);

    expect(
      withMission,
      withoutMission,
      reason:
          'Görev XP\'si ödül alınırken verilir; tur sonucu da eklerse aynı '
          'görev iki kez ödüllenir (B1).',
    );
    // Görev gerçekten tamamlandı ama ödülü alınmadı: ödül hâlâ bekliyor.
    final store = await DailyMissionStore.load();
    expect(store.missions.single.completed, isTrue);
    expect(store.missions.single.claimed, isFalse);
  });

  testWidgets('joker görevi tamamlanınca XP hemen yazılmaz', (tester) async {
    _resetStores();
    freshMockRepository();
    final repository = _RichRepository();
    await DailyMissionStore.loadForTest([
      DailyMission(type: MissionType.useWildcard, target: 1, coinReward: 20),
    ]);
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [
            QuizQuestion(
              id: 'b1-joker',
              category: 'Ziman',
              prompt: 'Pirtûk çi ye?',
              answers: ['Kitêb', 'Mase', 'Av', 'Mal'],
              correctAnswer: 'Kitêb',
              explanation: 'Pirtûk kitêb e.',
            ),
          ],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final button = find.byWidgetPredicate(
      (w) => w is WildcardButton && w.type == WildcardType.fiftyFifty,
    );
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final mission = (await DailyMissionStore.load()).missions.single;
    expect(mission.completed, isTrue, reason: 'joker görevi tamamlanmalı');
    expect((await XPStore.load()).totalXP, 0);
  });
}
