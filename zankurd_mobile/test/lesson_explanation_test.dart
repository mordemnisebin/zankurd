import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

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

/// Doğru şıkkın KAROSU doğru olarak işaretlenmiş mi?
///
/// Tur içi geri bildirim 2026-08-19'dan beri karonun kendisinden gelir:
/// doğru şık `correctGradient` ile yeşile döner ve tik alır. Altındaki
/// "Doğru cevap: X" kutusu kaldırıldı — aynı bilgiyi ikinci kez söylüyor
/// ve kıt olan dikey alanı kaplıyordu (uygulama sahibinin bildirimi).
bool dogruSikIsaretli(WidgetTester tester, String dogruSik) {
  final tile = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(dogruSik).first,
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final decoration = tile.decoration! as BoxDecoration;
  return decoration.gradient?.colors.first ==
      AppTheme.correctGradient.colors.first;
}

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
    // Geri bildirim KARODAN gelir, ayrı bir kutudan değil.
    expect(dogruSikIsaretli(tester, 'su'), isTrue);
    expect(find.text('Doğru cevap'), findsNothing);
  });

  testWidgets('doğru cevapta da açıklama metni açılmaz', (tester) async {
    await pumpQuiz(tester, MockZanKurdRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('su'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('«av» Türkçede «su» demektir.'), findsNothing);
    expect(dogruSikIsaretli(tester, 'su'), isTrue);
    expect(find.text('Doğru cevap'), findsNothing);
  });

  testWidgets('öğrenme modunda açıklama cevap ekranından açılabilir', (
    tester,
  ) async {
    await pumpQuiz(tester, MockZanKurdRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ekmek'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final explanationAction = find.byKey(
      const ValueKey('quiz-view-explanation'),
    );
    expect(explanationAction, findsOneWidget);

    await tester.tap(explanationAction);
    await tester.pumpAndSettle();
    expect(find.text('Açıklama'), findsOneWidget);
    expect(find.text('«av» Türkçede «su» demektir.'), findsOneWidget);
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

    // Korunan kural DEĞİŞMEDİ: açıklaması boş bir soruda da oyuncu
    // doğrusunu görmeli. Yalnız kaynağı değişti — kutu değil, karo.
    expect(dogruSikIsaretli(tester, 'su'), isTrue);
    expect(find.text('Doğru cevap'), findsNothing);
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

  testWidgets('öğrenme sonucu yarış başlığı kullanmaz', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockZanKurdRepository();

    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 100,
          correctCount: 1,
          wrongCount: 0,
          totalQuestions: 1,
          bestStreak: 1,
          coinsAwarded: 0,
          isLearningExperience: true,
          answerRecords: const [
            AnswerRecord(
              id: 'learning-result-1',
              category: 'Ziman',
              prompt: 'Peyva «av» çi ye?',
              answers: ['su', 'nan'],
              correctAnswer: 'su',
              selectedAnswer: 'su',
              explanation: '«av» su ye.',
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Öğrenme tamamlandı'), findsOneWidget);
    expect(find.text('Yarış tamamlandı'), findsNothing);
  });

  testWidgets('kelime sıralamada doğru cevap kutusu KALIR', (tester) async {
    // Bu testin tamamı bir silme kazasının bekçisidir.
    //
    // "Doğru cevap" kutusu 2026-08-19'da kaldırıldı çünkü çoktan seçmelide
    // karonun söylediğini ikinci kez söylüyordu. Ama kelime sıralamada
    // karo diye bir şey yok: cevap verilince girdi kilitleniyor ve doğru
    // dizilim HİÇBİR yerde görünmüyor. Kutu tümden silinseydi o türde
    // oyuncu yanlış yaptığında doğrusunu hiç öğrenemezdi.
    //
    // `needsAnswerRevealFallback` bu ayrımı tutar; bu test onun kelime
    // sıralama tarafını sabitler.
    const siralama = QuizQuestion(
      id: 'lesson-word-order',
      category: 'Ziman',
      type: QuestionType.wordOrdering,
      prompt: 'Peyvan rêz bike.',
      answers: ['Ez', 'diçim', 'malê'],
      correctAnswer: 'Ez diçim malê',
      explanation: '',
    );

    await pumpQuiz(tester, MockZanKurdRepository(), soru: siralama);
    await tester.pumpAndSettle();

    // Kelimeleri yanlış sırada gönder.
    await tester.tap(find.text('malê'));
    await tester.pump();
    await tester.tap(find.text('Ez'));
    await tester.pump();
    await tester.tap(find.text('diçim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kontrol et'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      find.text('Doğru cevap'),
      findsOneWidget,
      reason: 'kelime sıralamada doğru dizilimi açan tek yer bu kutu',
    );
    expect(find.text('Ez diçim malê'), findsWidgets);
  });

  test('yedek kutu yalnız kendi cevabını göstermeyen türde gerekir', () {
    // Tükenmiş `switch` sayesinde enum'a yeni bir tür eklenirse burası
    // değil, derleyici uyarır. Bu test yine de yürürlükteki kararı
    // okunur biçimde yazıya döker.
    expect(needsAnswerRevealFallback(QuestionType.multipleChoice), isFalse);
    expect(needsAnswerRevealFallback(QuestionType.trueFalse), isFalse);
    expect(needsAnswerRevealFallback(QuestionType.visual), isFalse);
    expect(needsAnswerRevealFallback(QuestionType.fillInBlank), isFalse);
    expect(needsAnswerRevealFallback(QuestionType.wordOrdering), isTrue);
  });
}
