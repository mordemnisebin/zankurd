import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

/// Ödül kuyruğa alındığında oyuncuya söylenmeli.
///
/// 2026-07-26: coin rozeti yalnız miktar sıfırdan büyükse çiziliyor.
/// Çevrimdışı bitirilen turda miktar sıfır olduğu için ekranda hiçbir iz
/// kalmıyor, oyuncu turu boşuna oynadığını sanıyordu. Ödül artık kuyrukta
/// beklediğine göre bunu söylemek doğru: kayıp değil, gecikme.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpResult(
    WidgetTester tester, {
    required int coinsAwarded,
    required bool rewardQueued,
  }) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 500,
          correctCount: 7,
          wrongCount: 3,
          totalQuestions: 10,
          bestStreak: 4,
          coinsAwarded: coinsAwarded,
          rewardQueued: rewardQueued,
          answerRecords: const [],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('ödül kuyruğa alındıysa bildirilir', (tester) async {
    await pumpResult(tester, coinsAwarded: 0, rewardQueued: true);

    expect(
      find.text('Bağlantı yok — ödülün kaydedildi, bağlanınca verilecek.'),
      findsOneWidget,
    );
  });

  testWidgets('ödül verildiyse ileti gösterilmez', (tester) async {
    // Karşı taraf: ileti her turda çıkarsa uyarı anlamını yitirir.
    await pumpResult(tester, coinsAwarded: 40, rewardQueued: false);

    expect(
      find.text('Bağlantı yok — ödülün kaydedildi, bağlanınca verilecek.'),
      findsNothing,
    );
  });
}
