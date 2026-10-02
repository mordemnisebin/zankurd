// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
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
    bool dailyCapReached = false,
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
          dailyCapReached: dailyCapReached,
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
      find.text('Bağlantı yok. Ödülün kaydedildi, bağlanınca verilecek.'),
      findsOneWidget,
    );
  });

  testWidgets('ödül verildiyse ileti gösterilmez', (tester) async {
    // Karşı taraf: ileti her turda çıkarsa uyarı anlamını yitirir.
    await pumpResult(tester, coinsAwarded: 40, rewardQueued: false);

    expect(
      find.text('Bağlantı yok. Ödülün kaydedildi, bağlanınca verilecek.'),
      findsNothing,
    );
  });

  // 2026-10-02 QA: tavana kalan 1 jetonken 17'lik bir tur "+1" verdi ve
  // ekran hiçbir şey söylemedi; tavan bildirimi yalnız `coinsAwarded <= 0`
  // iken çiziliyordu. Sunucu `cap_reached`i kısık ödülde de yolluyor.
  const capText = 'Bugünün jeton sınırına ulaştın. Yarın sıfırlanır.';

  testWidgets('tavan ödülü kıstıysa (+1) sebep söylenir', (tester) async {
    await pumpResult(
      tester,
      coinsAwarded: 1,
      rewardQueued: false,
      dailyCapReached: true,
    );
    expect(find.text(capText), findsOneWidget);
    expect(find.text('+1'), findsWidgets);
  });

  testWidgets('tavan ödülü sıfırladıysa sebep söylenir', (tester) async {
    await pumpResult(
      tester,
      coinsAwarded: 0,
      rewardQueued: false,
      dailyCapReached: true,
    );
    expect(find.text(capText), findsOneWidget);
  });

  testWidgets('tavana varılmadıysa tavan iletisi çıkmaz', (tester) async {
    await pumpResult(tester, coinsAwarded: 17, rewardQueued: false);
    expect(find.text(capText), findsNothing);
  });

  testWidgets('tavan tam ödemeyle dolduysa (istenen = verilen) ileti çıkmaz', (
    tester,
  ) async {
    // pumpResult: 7 doğru, seri 4 -> istenen 4 + 7 + 4 = 15.
    await pumpResult(
      tester,
      coinsAwarded: 15,
      rewardQueued: false,
      dailyCapReached: true,
    );
    expect(find.text(capText), findsNothing);
  });
}
