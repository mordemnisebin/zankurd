import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';

import 'support/widget_test_helpers.dart';

/// Yanlışta anında açıklama kartının bekçisi (2026-10-24).
///
/// ## Kusur
///
/// Yanlış yapan oyuncu doğru cevabı yalnız şık renginden görüyor, NEDEN
/// yanlış olduğunu turun sonunda (ya da hiç) öğreniyordu. 3750 sorunun
/// 3738'inde açıklama var ama tur sırasında hiç gösterilmiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Kuralın iki yüzü var ve ikisi de görünmez bozulur: kart yarış modlarına
/// (günün turu, düello, oda, bot) sızarsa rakibe karşı puanlanan turun
/// ritmi sessizce kesilir ve çevrimiçi odada cevap sızabilir; hiçbir
/// derleme hatası vermez. Kart HİÇ çıkmazsa da hiçbir şey kırılmaz — özellik
/// sessizce ölür.
///
/// ## Kural
///
/// Yalnız rakipsiz tek kişilik turda ([instantExplanationAllowedFor]) ve
/// yalnız YANLIŞTA: doğru şık işaretli, altında kısa açıklama, eylem
/// "Devam". Doğru cevapta kart yok. Dar ekranda (320) ve %200 yazıda iki
/// dilde taşma yok.
void main() {
  const soru = QuizQuestion(
    id: 'wrong-insight-1',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek', 'yol', 'dağ'],
    correctAnswer: 'su',
    explanation: '«av» Türkçede «su» demektir.',
    explanationKu: '«av» bi Tirkî «su» ye.',
    explanationTr: '«av» Türkçede «su» demektir.',
  );
  const sonrakiSoru = QuizQuestion(
    id: 'wrong-insight-2',
    category: 'Ziman',
    prompt: 'Peyva «nan» bi Tirkî çi tê gotin?',
    answers: ['ekmek', 'su', 'yol', 'dağ'],
    correctAnswer: 'ekmek',
    explanation: '«nan» Türkçede «ekmek» demektir.',
  );
  const aciklamasiz = QuizQuestion(
    id: 'wrong-insight-empty',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek', 'yol', 'dağ'],
    correctAnswer: 'su',
    explanation: '',
  );

  const kart = ValueKey('quiz-wrong-answer-insight');

  Future<void> pumpQuiz(
    WidgetTester tester, {
    List<QuizQuestion> sorular = const [soru, sonrakiSoru],
    QuizExperience experience = QuizExperience.competition,
    bool dailyQuiz = false,
    bool botRace = false,
    LanguageProvider? lang,
    double scale = 1.0,
  }) {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
    final repository = MockZanKurdRepository();
    return tester.pumpWidget(
      testShell(
        languageProvider: lang,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: QuizScreen(
              repository: repository,
              room: repository.createRoom(),
              questions: sorular,
              experience: experience,
              enableTimer: false,
              dailyQuiz: dailyQuiz,
              botRace: botRace,
            ),
          ),
        ),
      ),
    );
  }

  group('kapı: instantExplanationAllowedFor', () {
    bool izin({
      bool is1v1 = false,
      bool botRace = false,
      bool dailyQuiz = false,
      bool contest = false,
      bool versus = false,
      bool onlineRoom = false,
    }) => instantExplanationAllowedFor(
      is1v1: is1v1,
      botRace: botRace,
      dailyQuiz: dailyQuiz,
      contest: contest,
      versus: versus,
      onlineRoom: onlineRoom,
    );

    test('rakipsiz tek kişilik tur açık', () {
      expect(izin(), isTrue);
    });

    test('düello, bot yarışı, günün turu, yarışma, turnuva ve oda kapalı', () {
      expect(izin(is1v1: true), isFalse);
      expect(izin(botRace: true), isFalse);
      expect(izin(dailyQuiz: true), isFalse);
      expect(izin(contest: true), isFalse);
      expect(izin(versus: true), isFalse);
      expect(izin(onlineRoom: true), isFalse);
    });

    test('çeviri şeridiyle AYNI kuraldır (ikisi ayrışamaz)', () {
      for (var mask = 0; mask < 64; mask++) {
        final a = mask & 1 != 0;
        final b = mask & 2 != 0;
        final c = mask & 4 != 0;
        final d = mask & 8 != 0;
        final e = mask & 16 != 0;
        final f = mask & 32 != 0;
        expect(
          izin(
            is1v1: a,
            botRace: b,
            dailyQuiz: c,
            contest: d,
            versus: e,
            onlineRoom: f,
          ),
          translationRevealAllowedFor(
            is1v1: a,
            botRace: b,
            dailyQuiz: c,
            contest: d,
            versus: e,
            onlineRoom: f,
          ),
        );
      }
    });
  });

  group('solo tur', () {
    testWidgets('yanlışta doğru cevap + açıklama + "Devam" gelir', (
      tester,
    ) async {
      await pumpQuiz(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quiz-wrong-answer-explanation')),
        findsOneWidget,
      );
      expect(find.text('«av» Türkçede «su» demektir.'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('quiz-wrong-answer-correct')),
            )
            .textSpan!
            .toPlainText(),
        'Doğru cevap: su',
      );
      expect(find.text('Devam et'), findsOneWidget);
      expect(find.text('Sonraki'), findsNothing);

      // Eylem soruyu ilerletir.
      await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(kart), findsNothing);
      expect(find.text('Peyva «nan» bi Tirkî çi tê gotin?'), findsOneWidget);
    });

    // 2026-10-28 tur 3 T4: "Doğru cevap: X" YALNIZ BİR yerde durur. Kusur:
    // alt kırmızı şerit de aynı cümleyi yazıyor, içgörü kartı da; ekran aynı
    // bilgiyi iki kez söylüyordu. Sessizdi: iki yerin de ayrı testi vardı,
    // "toplamda bir kez" diye soran yoktu. Kart açıkken şerit yalnız "Yanlış"
    // + eylemdir.
    testWidgets('yanlışta "Doğru cevap" tek yerde: kart açıkken şerit yazmaz', (
      tester,
    ) async {
      await pumpQuiz(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsOneWidget);
      expect(find.textContaining('Doğru cevap'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuizFeedbackStrip),
          matching: find.textContaining('Doğru cevap'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(QuizFeedbackStrip),
          matching: find.text('Yanlış'),
        ),
        findsOneWidget,
      );
    });

    // W10 (2026-10-28 tur 5): doğruda da yanlışta da aynı eylem sözü:
    // "Devam et" (eskiden doğruda "Sonraki" idi).
    testWidgets('doğru cevapta kart YOK, eylem "Devam et"', (tester) async {
      await pumpQuiz(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('su'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsNothing);
      expect(find.text('«av» Türkçede «su» demektir.'), findsNothing);
      expect(find.text('Devam et'), findsOneWidget);
    });

    testWidgets('açıklaması olmayan soruda yalnız doğru cevap yazılır', (
      tester,
    ) async {
      await pumpQuiz(tester, sorular: const [aciklamasiz, sonrakiSoru]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quiz-wrong-answer-correct')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quiz-wrong-answer-explanation')),
        findsNothing,
      );
    });

    testWidgets('öğrenme modunda yanlışta kart "Açıklamayı gör" kapısının '
        'yerini alır (aynı açıklama iki yerde durmaz)', (tester) async {
      await pumpQuiz(tester, experience: QuizExperience.learning);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-view-explanation')), findsNothing);
    });

    testWidgets('Kurmancî arayüzde Kurmancî açıklama gelir', (tester) async {
      await pumpQuiz(tester, lang: kurmanciLang());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('«av» bi Tirkî «su» ye.'), findsOneWidget);
      expect(find.text('Bidomîne'), findsOneWidget);
    });
  });

  group('yarış modlarında kart YOK', () {
    testWidgets('günün turunda yanlış cevap açıklama göstermez', (
      tester,
    ) async {
      await pumpQuiz(tester, dailyQuiz: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsNothing);
      expect(find.text('«av» Türkçede «su» demektir.'), findsNothing);
      expect(find.text('Devam et'), findsOneWidget);
    });

    testWidgets('bot yarışında yanlış cevap açıklama göstermez', (
      tester,
    ) async {
      await pumpQuiz(tester, botRace: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ekmek'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byKey(kart), findsNothing);
      expect(find.text('«av» Türkçede «su» demektir.'), findsNothing);
    });
  });

  group('taşma yok: 320 genişlik, %200 yazı', () {
    for (final ku in [false, true]) {
      testWidgets(ku ? 'Kurmancî' : 'Türkçe', (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await pumpQuiz(
          tester,
          lang: ku ? kurmanciLang() : null,
          scale: 2.0,
          sorular: const [
            QuizQuestion(
              id: 'wrong-insight-long',
              category: 'Ziman',
              prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
              answers: ['su', 'ekmek', 'yol', 'dağ'],
              correctAnswer: 'su',
              explanation:
                  'Bu çok uzun bir açıklamadır: «av» sözcüğü Türkçede «su» '
                  'anlamına gelir; iki cümlelik açıklama dar ekranda ve büyük '
                  'yazıda da taşmadan sarmalıdır.',
              explanationKu:
                  'Ev şîroveyeke pir dirêj e: peyva «av» bi Tirkî «su» ye; '
                  'şîroveya du hevokî di ekrana teng û nivîsa mezin de jî '
                  'divê bê tijebûn bipêçe.',
            ),
            sonrakiSoru,
          ],
        );
        await tester.pumpAndSettle();

        // K6 (2026-10-28): soru artık açık kartta; %200 yazıda ilk şıklar
        // alt perdenin altında kalabilir, oyuncu kaydırır.
        await tester.ensureVisible(find.text('ekmek'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ekmek'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.byKey(kart), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
