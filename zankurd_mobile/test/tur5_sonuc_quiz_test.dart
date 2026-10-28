import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// 2026-10-28 tur 5 — soru sahnesi bekçileri (W12, W14).
///
/// ## W12 (iOS gezinti, ios_15)
///
/// Yanlış cevaptan sonra "Doğru cevap" açıklama kartı açılınca sahne onu
/// görünür alana kaydırıyordu; kayan gövde soru kartını üst kenarın arkasına
/// itiyor, sorunun ilk satırı kesiliyordu ("hangi savaş gerçekleşti?"). Hedef
/// "açıklama görünsün" idi, "soru da görünsün" değil.
///
/// Sessizdi çünkü: kaydırma test ortamında kapalıdır
/// (`isFlutterTestEnvironment`), kısa açıklamalarda içerik zaten sığar, ve
/// mevcut kaydırma bekçisi yalnız ALT kenarı (perde) ölçüyordu.
///
/// ## W2 / W13 (sonuç ekranı)
///
/// "Cevapları gör" "Diğer seçenekler"in ve katlanan "Ayrıntılar"ın içinde
/// saklıydı; kapalı satır "Dil 1/1 · Tarih 0/1 · K…" diye kesik özet
/// yazıyordu; alt perde iki eşit düğmeydi. "Seviye geçilmedi" SnackBar'ı
/// satırların üstüne biniyordu (Android gezinti and_17/18). Hiçbir test
/// alt perdenin ve SnackBar'ın İÇERİKLE çakışmasını ölçmüyordu.
///
/// ## W14 (ios_11 / and_11)
///
/// İlk quiz rehber balonu alt şeritteki "Sonraki" hedefini işaretlerken
/// ekranın ÜSTÜNE sabitleniyor ve soru kartını örtüyordu.
const _q = QuizQuestion(
  id: 'tur5-w12',
  category: 'Cîhan',
  prompt: 'Soğuk Savaş döneminde 1950 yılında hangi savaş gerçekleşti?',
  answers: [
    'Şerê Viyetnamê',
    'Şerê Çîn-Japonê',
    'Şerê Rûs-Japonê',
    'Şerê Koreyê',
  ],
  correctAnswer: 'Şerê Koreyê',
  explanation:
      "Kore Savaşı 25 Haziran 1950'de başladı ve 27 Temmuz 1953'te ateşkesle "
      "sona erdi. Bu savaş, Kuzey Kore (Çin ve Sovyetler Birliği'nin "
      "desteğiyle) ile Güney Kore (ABD ve Birleşmiş Milletler'in "
      'desteğiyle) arasında gerçekleşti.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> pumpQuiz(
    WidgetTester tester,
    Size size, {
    bool tutorialSeen = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final repository = freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': tutorialSeen,
      'zankurd.navTour.seen': true,
    });
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_q, _q],
          experience: QuizExperience.learning,
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(375, 667)]) {
    testWidgets(
      'W12: yanlıştan sonra açıklama açılınca soru kartının üstü görünür '
      '(${size.width.toInt()}x${size.height.toInt()})',
      (tester) async {
        revealCorrectAnswerInTests = true;
        addTearDown(() => revealCorrectAnswerInTests = false);
        await pumpQuiz(tester, size);
        final card = find.byKey(const ValueKey('quiz-prompt-card'));
        final scroll = find.byKey(const ValueKey('quiz-portrait-scroll'));
        expect(card, findsOneWidget);
        await tester.tap(find.text('Şerê Çîn-Japonê'), warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          find.byKey(const ValueKey('quiz-wrong-answer-insight')),
          findsOneWidget,
        );
        final viewport = tester.getRect(scroll);
        final cardRect = tester.getRect(card);
        // Telefon boyunda soru + şıklar + açıklama birlikte sığıyorsa kart
        // tam görünür; sığmıyorsa (667 pt) açıklama öncelik alır ama kart
        // YARIM kesik kalmaz: ya tam görünür ya tamamen kayar.
        final fullyVisible = cardRect.top >= viewport.top - 0.5;
        final fullyScrolledAway = cardRect.bottom <= viewport.top + 0.5;
        expect(
          fullyVisible || fullyScrolledAway,
          isTrue,
          reason: 'soru kartının ilk satırı yarım kesilmemeli',
        );
        if (size.height >= 800) expect(fullyVisible, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('W14: ilk quiz rehberi balonu soru kartını örtmez', (
    tester,
  ) async {
    await pumpQuiz(tester, const Size(390, 844), tutorialSeen: false);
    await tester.pump(const Duration(milliseconds: 600));
    // Adım 1 → 2 (hedef alt şeritteki "Sonraki").
    await tester.tap(find.byKey(const ValueKey('coach-mark-next')));
    await tester.pumpAndSettle();
    final title = find.text('Üst üste doğru ve sonraki soru');
    expect(title, findsOneWidget);
    final card = tester.getRect(find.byKey(const ValueKey('quiz-prompt-card')));
    final bubbleTitle = tester.getRect(title);
    final bubbleBody = tester.getRect(find.textContaining('Cevapladıktan'));
    expect(bubbleTitle.overlaps(card), isFalse, reason: 'başlık soruyu örter');
    expect(bubbleBody.overlaps(card), isFalse, reason: 'metin soruyu örter');
    expect(bubbleTitle.top, greaterThan(card.bottom));
  });

  group('W2/W13 sonuç ekranı', () {
    List<AnswerRecord> records(int wrong) => [
      for (var i = 0; i < 4; i++)
        AnswerRecord(
          id: 'r$i',
          category: i.isEven ? 'Ziman' : 'Dîrok',
          prompt: 'Pirs $i',
          answers: const ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: i < wrong ? 'B' : 'A',
          explanation: 'Şirove',
          explanationTr: 'Bu sorunun açıklaması $i numaralı satırdadır.',
        ),
    ];

    Future<void> pumpResult(
      WidgetTester tester, {
      required int wrong,
      bool levelGated = false,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final repository = freshMockRepository();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repository,
            room: repository.createRoom(),
            score: (4 - wrong) * 100,
            correctCount: 4 - wrong,
            wrongCount: wrong,
            totalQuestions: 4,
            bestStreak: 1,
            coinsAwarded: 0,
            answerRecords: records(wrong),
            levelGated: levelGated,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    // 2026-10-29 tur 6 Y1: "Cevapları gör" artık tam genişlik çerçeveli
    // ikincil düğme; yanlış sayısı parantez değil ROZET (turuncu metin yok).
    // "Diğer seçenekler" satırı kalktı; yerine alt perdede "⋯" düğmesi.
    testWidgets(
      'W2/Y1: görünür "Cevapları gör" + yanlış rozeti alt perdenin üstünde',
      (tester) async {
        await pumpResult(tester, wrong: 2);
        final see = find.byKey(const ValueKey('result-see-answers-button'));
        expect(see, findsOneWidget);
        expect(find.text('Cevapları gör'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('result-see-answers-badge')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Cevapları gör (2 yanlış)'),
          findsOneWidget,
        );
        final seeRect = tester.getRect(see);
        final primary = tester.getRect(
          find.byKey(const ValueKey('result-play-again-button')).first,
        );
        expect(seeRect.bottom, lessThanOrEqualTo(primary.top + 1));
        expect(seeRect.height, greaterThanOrEqualTo(44));
        // Kapalı "Ayrıntılar" satırında kesik özet yok: yalnız ad + sayı.
        final header = find.byKey(const ValueKey('result-collapsible-header'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.textContaining('/')),
          findsNothing,
          reason: 'kategori 1/2 gibi kesik özet yazılmaz',
        );
        // Y1: birimli ad — çıplak "3" yok ("Ayrıntılar · 2 konu").
        expect(
          find.descendant(
            of: header,
            matching: find.text('Ayrıntılar · 2 konu'),
          ),
          findsOneWidget,
        );
        // Alt perde: tam genişlik birincil + simge olarak Paylaş.
        final share = find.byKey(const ValueKey('result-share-button'));
        expect(tester.getSize(share).width, lessThanOrEqualTo(64));
        expect(tester.getSize(share).height, greaterThanOrEqualTo(48));
        expect(
          find.descendant(of: share, matching: find.text('Paylaş')),
          findsNothing,
        );
        expect(
          primary.width,
          greaterThan(200),
        ); // Y1: üç düğmeli satır (birincil + paylaş + ⋯)

        // Dokununca bölüm açılır ve cevap listesi görünür.
        await tester.tap(see);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('result-all-explanations')),
          findsOneWidget,
        );
      },
    );

    testWidgets('W2: hiç yanlış yoksa düğme sade "Cevapları gör"', (
      tester,
    ) async {
      await pumpResult(tester, wrong: 0);
      expect(find.text('Cevapları gör'), findsOneWidget);
    });

    testWidgets('W13: seviye geçilmedi satır içi; SnackBar yok', (
      tester,
    ) async {
      await pumpResult(tester, wrong: 3, levelGated: true);
      expect(
        find.byKey(const ValueKey('result-level-not-passed')),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Seviye geçilmedi'), findsOneWidget);
    });

    testWidgets('W13: geçilen seviyede ya da seviye dışı turda satır yok', (
      tester,
    ) async {
      await pumpResult(tester, wrong: 0, levelGated: true);
      expect(
        find.byKey(const ValueKey('result-level-not-passed')),
        findsNothing,
      );
      await pumpResult(tester, wrong: 3);
      expect(
        find.byKey(const ValueKey('result-level-not-passed')),
        findsNothing,
      );
    });
  });
}
