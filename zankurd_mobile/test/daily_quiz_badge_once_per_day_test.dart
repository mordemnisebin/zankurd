// Bekçi: "Günün soruları x5" rozeti günde en fazla bir sayım alır (B3).
//
// ## Kusur
// `AchievementStore.recordQuizResult(dailyQuiz: true)` her turda sayacı
// artırıyordu. Günün soruları turu aynı gün tekrar oynanabildiği için
// `daily_quiz_five` rozeti ("5 kez tamamladın") tek günde açılabiliyordu.
//
// ## Niçin sessiz kalırdı
// Mevcut test aynı gün içinde beş tur çağırıp rozetin AÇILDIĞINI bekliyordu;
// yani hatayı doğru davranış diye sabitliyordu.
//
// ## Kural
// Sayaç yerel takvim gününde en çok bir kez artar. Beş FARKLI günde
// tamamlanınca rozet açılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
  });

  test('aynı gün beş tekrar rozeti açmaz', () async {
    final store = await AchievementStore.load();
    for (var i = 0; i < 5; i++) {
      await store.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 5,
        correctCount: 3,
        bestStreak: 1,
        dailyStreak: 1,
        userScore: 100,
        dailyQuiz: true,
      );
    }
    expect(store.isUnlocked(AchievementIds.dailyQuizFive), isFalse);
  });

  test('beş farklı günde rozet açılır', () async {
    final store = await AchievementStore.load();
    for (var day = 1; day <= 5; day++) {
      await store.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 5,
        correctCount: 3,
        bestStreak: 1,
        dailyStreak: 1,
        userScore: 100,
        dailyQuiz: true,
        now: DateTime(2026, 10, day, 12),
      );
    }
    expect(store.isUnlocked(AchievementIds.dailyQuizFive), isTrue);
  });

  test('saat 24→23→24 oynatılınca aynı takvim günü tekrar sayılmaz', () async {
    final store = await AchievementStore.load();
    // Aynı gerçek gün: saat ileri-geri oynatılıyor.
    for (final day in [24, 23, 24, 23, 24, 23, 24]) {
      await store.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 5,
        correctCount: 3,
        bestStreak: 1,
        dailyStreak: 1,
        userScore: 100,
        dailyQuiz: true,
        now: DateTime(2026, 10, day, 12),
      );
    }
    expect(store.isUnlocked(AchievementIds.dailyQuizFive), isFalse);
  });
}
