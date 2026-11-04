// R9 (GPT-6 Pro alan 2) akış/durum bekçileri.
//
// 1) Yerel puanlama cümle kurmada yalnız ana cümleyi doğru sayıyordu;
//    `acceptedAnswers` alternatif dizilimleri modelde geçerliyken puanda
//    yanlıştı (puan + yanlış/SRS kaydı içerikle çelişirdi). Sessizdi:
//    hata fırlamaz, yalnız geçerli cevap "yanlış" yazılırdı.
// 2) Görev ödülü eski görev NESNESİ üzerinden alınıyordu: eşitleme deposu
//    yenileyince eski nesnede `claimed=false` kalıyor, aynı ödül yeniden
//    alınabiliyordu.
// 3) Günlük sınav sayacı iki cihaz birleşiminde 5'ten 1'e düşebiliyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyMissionStore.resetInstance();
  });

  test('yerel puanlama cümle kurmada alternatif dizilimi kabul eder', () async {
    const question = QuizQuestion(
      id: 'wo-test',
      category: 'Ziman',
      prompt: 'Cümleyi kur',
      answers: ['hewa', 'îro', 'germ', 'e'],
      correctAnswer: 'hewa îro germ e',
      acceptedAnswers: ['îro hewa germ e'],
      explanation: '',
      type: QuestionType.wordOrdering,
    );
    final repo = MockZanKurdRepository();
    const room = GameRoom(
      id: null,
      name: 'x',
      code: '',
      category: 'Ziman',
      players: [],
      status: RoomStatus.active,
    );
    Future<bool> correct(String sentence) async {
      final result = await repo.submitAnswer(
        room: room,
        question: question,
        selectedOptionOptionKey: sentence,
        responseMs: 1000,
      );
      return result['is_correct'] == true;
    }

    expect(await correct('hewa îro germ e'), isTrue);
    expect(await correct('îro hewa germ e'), isTrue);
    expect(await correct('germ e hewa îro'), isFalse);
  });

  test('görev ödülü güncel deponun görevine göre bir kez alınır', () async {
    DailyMission mk() =>
        DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 10)
          ..completed = true;
    final stale = mk();
    final live = mk();
    final store = await DailyMissionStore.loadForTest([live]);

    var grants = 0;
    expect(await store.claimRewardAfter(live, () async => grants++), isTrue);
    // Ekran eski nesneyi tutuyor (claimed=false): ikinci alım reddedilmeli.
    expect(stale.claimed, isFalse);
    expect(await store.claimRewardAfter(stale, () async => grants++), isFalse);
    expect(grants, 1);
    expect(stale.claimed, isTrue);
  });

  test('günlük sınav sayacı birleşimde geri gitmez', () {
    const five = SnapshotAchievements(dailyQuiz: 5, dailyQuizDay: '2026-10-01');
    const one = SnapshotAchievements(dailyQuiz: 1, dailyQuizDay: '2026-10-20');
    final merged = SnapshotAchievements.merge(five, one);
    expect(merged.dailyQuiz, 5);
    expect(merged.dailyQuizDay, '2026-10-20');
  });
}
