import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Açıklamanın **nerede** gösterileceğinin bekçisi.
///
/// 2026-07-26: uygulama sahibi bunu birkaç kez bildirdi — şık işaretlenir
/// işaretlenmez altında bir paragraf açılıyor, tur duruyor ve okuma yükü
/// oyunun ritmini kesiyordu. Kural değişti:
///
/// * tur sırasında **yalnız doğru cevap** görünür;
/// * açıklamaların tamamı sorular bittiğinde sonuç ekranında **bir arada**
///   gelir (`_AllExplanationsCard`).
///
/// İki taraf birlikte sabitleniyor. Yalnız birini yazmak kuralı yarım
/// bırakır: açıklamayı turdan kaldırıp sonuca koymayı unutmak, öğrenme
/// alanını sessizce boşaltır.
void main() {
  const question = QuizQuestion(
    id: 'lesson-expl-1',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek', 'yol', 'dağ'],
    correctAnswer: 'su',
    explanation: '«av» Türkçede «su» demektir.',
  );

  Future<void> pumpQuiz(
    WidgetTester tester,
    MockZanKurdRepository repository, {
    QuizQuestion soru = question,
  }) {
    // Koçmark açık kalırsa şıkkın üstünü kapatır ve dokunuş cevaba ulaşmaz;
    // test o zaman açıklamayı değil, öğreticiyi ölçer.
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
    return tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [soru],
          experience: QuizExperience.learning,
          enableTimer: false,
        ),
      ),
    );
  }

  testWidgets('tur sırasında yalnız doğru cevap gösterilir', (tester) async {
    await pumpQuiz(tester, MockZanKurdRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ekmek'));
    // Açıklama kutusu 800 ms'lik bir denetleyicinin sonunda açılırdı; o süre
    // dolduktan sonra bile metin görünmemeli.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('«av» Türkçede «su» demektir.'), findsNothing);
    expect(find.text('Doğru cevap'), findsOneWidget);
  });

  testWidgets('doğru cevapta da açıklama metni açılmaz', (tester) async {
    await pumpQuiz(tester, MockZanKurdRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('su'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('«av» Türkçede «su» demektir.'), findsNothing);
    expect(find.text('Doğru cevap'), findsOneWidget);
  });

  testWidgets('açıklaması olmayan soruda da doğru cevap gösterilir', (
    tester,
  ) async {
    // `de45f05` açıklama metnini turdan kaldırdı ama kutunun **görünürlük
    // koşulunu** kaldırmadı: kutu, artık basmadığı `explanation` alanı boş
    // diye tümden gizleniyordu. Açıklaması olmayan 15 soruda (hepsi
    // topluluk bankasında) oyuncu şıkkı işaretliyor ve hiçbir geri
    // bildirim görmüyordu — doğru cevabı bile.
    //
    // Kusur sessizdi çünkü buradaki iki durum da açıklaması **olan** bir
    // soru kullanıyor; boş alan hiç sınanmamıştı. Ekran turu da o 15
    // soruyu basmıyor.
    const aciklamasiz = QuizQuestion(
      id: 'lesson-expl-empty',
      category: 'Ziman',
      prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
      answers: ['su', 'ekmek', 'yol', 'dağ'],
      correctAnswer: 'su',
      explanation: '',
    );

    await pumpQuiz(tester, MockZanKurdRepository(), soru: aciklamasiz);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ekmek'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Doğru cevap'), findsOneWidget);
    expect(find.text('su'), findsWidgets);
  });

  testWidgets('sonuç ekranı bütün açıklamaları bir arada gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockZanKurdRepository();

    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 100,
          correctCount: 1,
          wrongCount: 1,
          totalQuestions: 2,
          bestStreak: 1,
          coinsAwarded: 0,
          answerRecords: const [
            AnswerRecord(
              id: 'r1',
              category: 'Ziman',
              prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
              answers: ['su', 'ekmek'],
              correctAnswer: 'su',
              selectedAnswer: 'su',
              explanation: '«av» Türkçede «su» demektir.',
            ),
            AnswerRecord(
              id: 'r2',
              category: 'Ziman',
              prompt: 'Peyva «nan» bi Tirkî çi tê gotin?',
              answers: ['ekmek', 'su'],
              correctAnswer: 'ekmek',
              selectedAnswer: 'su',
              explanation: '«nan» Türkçede «ekmek» demektir.',
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Kart listenin en sonunda; görünür olması için oraya kaydırılır.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('result-all-explanations')),
      300,
    );
    await tester.pumpAndSettle();

    expect(find.text('Turun açıklamaları'), findsOneWidget);
    expect(find.text('«av» Türkçede «su» demektir.'), findsOneWidget);
    expect(find.text('«nan» Türkçede «ekmek» demektir.'), findsOneWidget);
  });
}
