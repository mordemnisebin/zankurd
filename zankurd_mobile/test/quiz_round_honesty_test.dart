// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
/// Sonuç ve soru ekranı turu DÜRÜST anlatır mı: gerçekte hangi
/// kategorilerin çözüldüğü, hangi kategoride ne kadar doğru yapıldığı ve
/// dördüncü şıkkın cevaplamadan ÖNCE gerçekten görünüp görünmediği.
///
/// ## Kusur
///
/// Canlı simülatör turunda (2026-09-27, iPhone 17 — 402×874 pt, metin
/// ölçeği 1.0) üç ayrı yalan/eksiklik görüldü, üçü de "günün dersi" gibi
/// KARIŞIK kategorili bir turda ortaya çıkıyor:
///
/// 1. Tur Müzik/Dil/Coğrafya/Dil/Kültür karışık beş sorudan oluşuyordu ama
///    sonuç ekranı "Dil · %80 doğruluk" yazdı. `room.category` odanın
///    varsayılan/ilk kategorisidir — GERÇEKTEN çözülen soruların kategorisi
///    değil (`home_screen.dart` `_startDailyQuiz`, `room.category`yi hiç
///    güncellemeden `repo.createRoom()`ın varsayılanını taşır).
/// 2. Aynı ekranın "Nerelerde zorlandın?" kutusu yalnız "Dil: 2 sorunun
///    2'si doğru" satırını gösterdi; Müzik 1/1, Coğrafya 1/1, Kültür 0/1
///    hiç yazılmadı. `LearningOutcome`, kategori başına yalnız TEK "en
///    güçlü" ve TEK "tekrar" satırı seçiyordu; ikisinin eşiği de
///    (`answered >= 2`) kategori başına genelde tek soru düşen karışık
///    turlarda neredeyse hiç tutmuyor ve geri kalan kategoriler sessizce
///    kayboluyordu.
/// 3. Görselli (`QuestionType.visual`, görsel + dört şık) bir soruda D
///    şıkkı ekranın altında kaldı: `_buildQuestionPanel` şıklara ayırdığı
///    bütçeyi (`contentBudget`) görsel hiç yokmuş gibi hesaplıyordu; görsel
///    kartın içine kendi yüksekliğinde bir kutu olarak eklenince kart
///    gerçek `minHeight`i tam görselin kapladığı kadar aşıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// (1) ve (2): Hiçbir test birden fazla kategoriden soru içeren bir tur
/// kurmuyordu. `learning_outcome_card_test.dart`daki turlar hep 1-2
/// kategoriden, kategori başına 2+ soruyla kuruluydu — yani tam da
/// spotlight eşiğinin ÜSTÜNDE. "Günün dersi"nin gerçek şekli — kategori
/// başına çoğu zaman TEK soru, 3-5 farklı kategori — hiç ölçülmedi; hem
/// kategori etiketi hem öğrenme özeti kusuru ancak o şekilde ortaya çıkar.
///
/// (3): Varsayılan test koşucusu 800×600'dür ve geometriyi gizler (bkz.
/// `support/widget_test_helpers.dart` başlığı). Gerçek 402×874 yüzeyde
/// görsel soruyu ölçen TEK test (`quiz_flow_test.dart` "visual quiz keeps
/// the next action visible in landscape") YATAY (844×390) ölçüyordu; o
/// dalda görsel metnin YANINDA durur, dikey bütçeyi hiç paylaşmaz. Dikey
/// (portrait) dalda görselin ÜSTTEN çaldığı alan hiç ölçülmemişti.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/learning_outcome_card.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

AnswerRecord _record(String id, String category, {required bool correct}) =>
    AnswerRecord(
      id: id,
      category: category,
      prompt: 'Pirs $id',
      answers: const ['A', 'B'],
      correctAnswer: 'A',
      selectedAnswer: correct ? 'A' : 'B',
      explanation: 'Şirove',
    );

/// Canlı turdaki karışık kategori seti: Müzik, Dil, Coğrafya, Dil, Kültür.
List<AnswerRecord> _mixedRoundRecords() => [
  _record('1', 'Muzîk', correct: true),
  _record('2', 'Ziman', correct: true),
  _record('3', 'Cografya', correct: true),
  _record('4', 'Ziman', correct: true),
  _record('5', 'Çand', correct: false),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Kusur 1: karışık turda kategori etiketi', () {
    testWidgets(
      'karışık kategorili turda kategori adı değil TURUN ADI yazılır',
      (tester) async {
        final repository = MockZanKurdRepository();
        final room = repository
            .createRoom(category: 'Ziman')
            .copyWith(name: 'Günün dersi');

        await tester.pumpWidget(
          testShell(
            child: QuizResultScreen(
              repository: repository,
              room: room,
              score: 0,
              correctCount: 4,
              wrongCount: 1,
              totalQuestions: 5,
              bestStreak: 2,
              answerRecords: _mixedRoundRecords(),
              coinsAwarded: 0,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // 2026-09-29 Şahnê: turun adı sahnenin üst satırındaki bağlamda
        // ("Günün dersi • 5 soru") yazılır; doğruluk puanın altındadır.
        // Korunan kural aynı: karışık turda kategori adı değil TURUN ADI.
        expect(
          find.text('Dil • 5 soru'),
          findsNothing,
          reason:
              'Karışık turda hâlâ TEK kategoriymiş gibi "Dil" yazıyor '
              '(room.category odanın varsayılanıdır, turun içeriği değil).',
        );
        expect(find.text('Günün dersi • 5 soru'), findsOneWidget);
      },
    );

    testWidgets('tek kategorili turda bugünkü davranış (kategori adı) kalır', (
      tester,
    ) async {
      final repository = MockZanKurdRepository();
      final records = [
        _record('1', 'Ziman', correct: true),
        _record('2', 'Ziman', correct: true),
        _record('3', 'Ziman', correct: true),
        _record('4', 'Ziman', correct: false),
        _record('5', 'Ziman', correct: true),
      ];

      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repository,
            room: repository.createRoom(category: 'Ziman'),
            score: 0,
            correctCount: 4,
            wrongCount: 1,
            totalQuestions: 5,
            bestStreak: 2,
            answerRecords: records,
            coinsAwarded: 0,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // 2026-09-29 Şahnê: bağlam sahnenin üst satırında (bkz. yukarı).
      expect(find.text('Dil • 5 soru'), findsOneWidget);
    });
  });

  group('Kusur 2: eksik öğrenme özeti', () {
    test(
      'karışık turda spotlight dışı kategoriler eşiksiz sayımla listelenir',
      () {
        final outcome = LearningOutcome.fromRecords(_mixedRoundRecords());

        // Karar (2026-10-02 güncellemesi): güçlü konu eşiği (`answered >= 2`)
        // KORUNDU — tek soruluk sinyali "en güçlü" ilan ETMEZ. Ama ZAYIF
        // konu artık eşiğe bağlı değil: en az bir yanlışı olan kategoriler
        // arasında en düşük doğruluk (bkz. `LearningOutcome.fromRecords`).
        // Eskiden Kültür 0/1 spotlight'a giremiyor, "Nerelerde zorlandın?"
        // başlığının altında yalnız güçlü konu yazıyordu. Spotlight'a
        // girmeyenler eşiksiz sayımla listelenmeye devam eder.
        expect(outcome.strongestCategory, 'Ziman');
        expect(outcome.reviewCategory, 'Çand');
        expect(outcome.reviewWrong, 1);
        expect(outcome.categoryBreakdown.map((c) => c.category).toList(), [
          'Muzîk',
          'Ziman',
          'Cografya',
          'Çand',
        ]);

        final leftover = outcome.categoryBreakdown
            .where(
              (c) =>
                  c.category != outcome.strongestCategory &&
                  c.category != outcome.reviewCategory,
            )
            .toList();
        expect(leftover.map((c) => (c.category, c.answered, c.correct)), [
          ('Muzîk', 1, 1),
          ('Cografya', 1, 1),
        ]);
      },
    );

    testWidgets(
      'öğrenme özeti kutusu Müzik/Coğrafya/Kültür satırlarını da basar',
      (tester) async {
        final outcome = LearningOutcome.fromRecords(_mixedRoundRecords());

        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: LearningOutcomeCard(outcome: outcome, onReview: () {}),
            ),
          ),
        );

        expect(find.text('Nerelerde zorlandın?'), findsOneWidget);
        // Spotlight: en güçlü kategori (2+ cevap, %75+ doğru) eskisi gibi
        // öne çıkar.
        expect(find.textContaining("Dil: 2 sorudan 2 doğru"), findsOneWidget);
        // Eskiden burada hiçbir şey yazmıyordu (2026-09-27 canlı turu).
        expect(
          find.textContaining("Müzik: 1 sorudan 1 doğru"),
          findsOneWidget,
          reason: 'Tek soruluk Müzik kategorisi özetten kayboldu.',
        );
        expect(
          find.textContaining("Coğrafya: 1 sorudan 1 doğru"),
          findsOneWidget,
          reason: 'Tek soruluk Coğrafya kategorisi özetten kayboldu.',
        );
        // 2026-10-02: tek yanlış artık zayıf konu satırıdır (sayım satırı
        // değil): başlığın sorduğu şeyi cevaplar.
        expect(
          find.textContaining("Kültür: 1 soruda 1 yanlış"),
          findsOneWidget,
          reason: 'Tek yanlışlı Kültür kategorisi özetten kayboldu.',
        );
      },
    );

    testWidgets(
      'tek kategorili turda ek satır basılmaz (bugünkü davranış kalır)',
      (tester) async {
        final outcome = LearningOutcome.fromRecords([
          _record('1', 'Ziman', correct: true),
        ]);

        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: LearningOutcomeCard(outcome: outcome, onReview: null),
            ),
          ),
        );

        // Tek kategoride liste hep boştur (üstteki toplam satırının
        // birebir tekrarı olurdu); bugünkü genel öneri metni kalmalı.
        expect(
          find.textContaining('Ji bo nirxandina mijarekê').evaluate().isEmpty,
          isTrue,
        );
        expect(find.textContaining("sorudan 1 doğru"), findsNothing);
      },
    );
  });

  group('Kusur 3: görselli soruda D şıkkı ekran dışında', () {
    testWidgets(
      '402×874 iPhone yüzeyinde görselli dört şıklı soruda son şık görünür '
      'alanda kalır',
      (tester) async {
        await tester.binding.setSurfaceSize(kPhoneSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const question = QuizQuestion(
          id: 'visual-portrait-fit',
          category: 'Çand',
          prompt: 'Görseldeki etkinlik hangi kültürel kategoriyle ilgilidir?',
          answers: ['Coğrafya', 'Ziman', 'Müzik', 'Edebiyat'],
          correctAnswer: 'Müzik',
          explanation: 'Govend kültürel bir dans ve müzik etkinliğidir.',
          type: QuestionType.visual,
          imageUrl: 'asset://assets/zankurd.webp',
        );

        final repository = freshMockRepository();
        await tester.pumpWidget(
          testShell(
            child: withDeviceInsets(
              QuizScreen(
                repository: repository,
                room: repository.createRoom(),
                questions: const [question],
                enableTimer: false,
                // Öğrenme deneyiminde karta yalnız "Sonraki" düşer ve şık
                // bütçesi rekabet moduna göre çok daha büyüktür (bkz.
                // `_buildQuestionPanel` yorumu); kusur en belirgin BURADA
                // ortaya çıkıyordu — "günün dersi" zaten hep bu modu kullanır.
                experience: QuizExperience.learning,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final optionTiles = find.byType(QuizOptionTile);
        expect(
          optionTiles,
          findsNWidgets(4),
          reason: 'Dört şıklı soru dört QuizOptionTile bekler.',
        );
        final rects = [
          for (var i = 0; i < 4; i++) tester.getRect(optionTiles.at(i)),
        ]..sort((a, b) => a.top.compareTo(b.top));
        final dOption = rects.last;

        expect(
          dOption.bottom,
          lessThanOrEqualTo(kPhoneSize.height - kPhoneInsets.bottom),
          reason: 'D şıkkının alt kenarı görünür alanın dışında ($dOption).',
        );
        expect(
          dOption.height,
          greaterThanOrEqualTo(44),
          reason:
              'Dokunma hedefi erişilebilirlik tabanının (44pt) altına indi.',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('görselsiz soruda dört şıklı düzen değişmez', (tester) async {
      await tester.binding.setSurfaceSize(kPhoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const question = QuizQuestion(
        id: 'text-only-portrait-fit',
        category: 'Çand',
        prompt: 'Bu soru görselsizdir; düzen sabit kalmalı.',
        answers: ['Coğrafya', 'Ziman', 'Müzik', 'Edebiyat'],
        correctAnswer: 'Müzik',
        explanation: 'Açıklama.',
      );

      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: withDeviceInsets(
            QuizScreen(
              repository: repository,
              room: repository.createRoom(),
              questions: const [question],
              enableTimer: false,
              experience: QuizExperience.learning,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final optionTiles = find.byType(QuizOptionTile);
      expect(optionTiles, findsNWidgets(4));
      final rects = [
        for (var i = 0; i < 4; i++) tester.getRect(optionTiles.at(i)),
      ]..sort((a, b) => a.top.compareTo(b.top));
      expect(
        rects.last.bottom,
        lessThanOrEqualTo(kPhoneSize.height - kPhoneInsets.bottom),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
