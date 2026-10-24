import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/kilim_motifs.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Soru ekranının renk ve yüzey kuralları.
///
/// 2026-10-19 SADELEŞME (bu dosya güncellendi): (1) şık çubuğunun halkası
/// artık yuvarlak köşeli şekildedir (`OutlinedBorder`; eskiden pahlı);
/// (2) 5'li/10'lu elmas dizisi kalktı, yerine 4 px'lik ince ilerleme çubuğu
/// geldi: "elmas dizisi turun kaydını taşır" testi "ilerleme çubuğu turun
/// kaydını taşır" oldu ve çubuğun doluluğunu (tamamlanan/toplam) ile ekran
/// okuyucu özetindeki doğru sayısını ölçer. Renk kuralları aynı.
///
/// 2026-09-29 Şahnê: bekçiler eski görünüşü (Forest seçim gradyanı, şık
/// kimlik rengi kenarlığı, turuncu marka dolgusu, kilim tahtası, 3D gölge,
/// Zana yüzü) sabitliyordu; soru ekranı Şahnê C iskeletine taşınınca
/// yeni kurallara çevrildi. Korunan KURALLAR aynı:
///
/// * cevaptan önce şıkta RENK YOK (seçim yalnız halka alır) — renk cevabı
///   ele verirdi;
/// * açıklanınca doğru Rast, seçilen yanlış Şaş (+ ✓/✗; durum yalnız
///   renkle verilmez);
/// * tek birincil eylem Agir dolgudur; cevaptan önce yarışmada onun yerini
///   jokerler alır;
/// * ilerleme turun KAYDINI tutar (kaçıncı soru, hangileri doğru);
/// * şık yüzeyi gölgesiz; şıkların arkasında desen yok; maskot yok.

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => SoundProvider()),
    ChangeNotifierProvider<ReducedMotionProvider>(
      create: (_) => ReducedMotionProvider(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  SahneTokens tokensAt(WidgetTester tester, String text) =>
      SahneTokens.of(tester.element(find.text(text).first));

  AnimatedContainer barOf(WidgetTester tester, String answer) =>
      tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(answer).first,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

  /// Şık çubuğunun içe çizilen halkası (ön plan kenarı).
  BorderSide ringOf(WidgetTester tester, String answer) {
    final box = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.text(answer).first,
            matching: find.byType(DecoratedBox),
          ),
        )
        .firstWhere((d) => d.position == DecorationPosition.foreground);
    final shape = (box.decoration as ShapeDecoration).shape;
    return (shape as OutlinedBorder).side;
  }

  testWidgets('kontrol edilen şık renksiz kalır, yalnız halka alır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: QuizOptionTile(
            index: 0,
            answer: 'Dersim',
            selected: true,
            correct: false,
            disabled: false,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final t = tokensAt(tester, 'Dersim');
    final decoration = barOf(tester, 'Dersim').decoration! as BoxDecoration;
    expect(decoration.color, t.s2);
    expect(decoration.gradient, isNull, reason: 'cevaptan önce renk yok');
    final ring = ringOf(tester, 'Dersim');
    expect(ring.color, t.tx);
    expect(ring.width, SahneRing.r2);
  });

  testWidgets('cevaplanmamış şıklar aynı nötr yüzeyi ve renksiz harfi taşır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sahne her zaman gece: gündüz temasında da gece belirteçleri.
    const t = SahneTokens.night;
    for (final answer in question.displayAnswers) {
      final decoration = barOf(tester, answer).decoration! as BoxDecoration;
      // Tur 8: dinlenme dolgusu bir ton açık (optionFill) + 1 px kenar.
      // D aşaması: dinlenme dolgusu ve kenarı soru konusunun tonuna doğru
      // ölçülü kayar (düz gri değil); harf karosu renksiz kalır.
      final tone = CategoryVisuals.tone(question.category);
      expect(decoration.color, t.optionFillFor(tone));
      expect(decoration.color, isNot(t.optionFill));
      expect(decoration.gradient, isNull);
      expect(ringOf(tester, answer).color, t.optionEdgeFor(tone));
      expect(ringOf(tester, answer).width, 1);
    }
    // Harf karoları (A/B/C/D) hepsi aynı tonda (optionLetterFill): harfe göre renk yok.
    for (final letter in ['A', 'B', 'C', 'D']) {
      final tile = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(letter).first,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect((tile.decoration! as ShapeDecoration).color, t.optionLetterFill);
    }
  });

  testWidgets('açıklanınca doğru Rast, seçilen yanlış Şaş ve ✓/✗ alır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    final wrongAnswer = question.displayAnswers.firstWhere(
      (answer) => answer != question.correctAnswer,
    );
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(of: find.text(wrongAnswer), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    const t = SahneTokens.night;
    final right =
        barOf(tester, question.correctAnswer).decoration! as BoxDecoration;
    final wrong = barOf(tester, wrongAnswer).decoration! as BoxDecoration;
    // Tarama bitti: dolgu çubuğun tamamında.
    expect(right.gradient!.colors.first, t.okFill);
    expect(right.gradient!.stops![1], 1.0);
    expect(wrong.gradient!.colors.first, t.errFill);
    expect(ringOf(tester, question.correctAnswer).color, t.okTx);
    expect(ringOf(tester, wrongAnswer).color, t.errTx);
    expect(find.byKey(const ValueKey('correct_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('wrong_icon')), findsOneWidget);
  });

  testWidgets('cevaptan önce jokerler, cevaptan sonra tek Agir "Sonraki"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    const next = ValueKey('quiz-next-button');
    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);
    expect(find.byKey(next), findsNothing);

    await tester.tap(find.text(question.correctAnswer).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsNothing);
    expect(tester.widget<SahneButton>(find.byKey(next)).onPressed, isNotNull);
    final fill = tester.widget<Material>(
      find.descendant(of: find.byKey(next), matching: find.byType(Material)),
    );
    expect(fill.color, SahneTokens.night.act);
  });

  // Eski adı: "kilim tahtası turun kaydını taşır", sonra "elmas dizisi ...".
  // 2026-10-19'da şerit 4 px'lik ince çubuğa geçti. Korunan kural aynı:
  // şerit turun KAYDINI tutar — kaç soru tamamlandı ve kaçı doğruydu. Kayıt
  // bileşenin aldığı değerlerden okunur, boyanan pikselden değil.
  testWidgets('ilerleme çubuğu turun kaydını taşır', (tester) async {
    final repository = MockZanKurdRepository();
    final questions = repository.questions.take(3).toList();
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: questions,
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    SahneProgressBar bar() => tester.widget<SahneProgressBar>(
      find.byKey(const ValueKey('quiz-progress-bar')),
    );

    expect(bar().height, 4);
    expect(find.byType(SahneDiamondRow), findsNothing);
    expect(bar().value, 0, reason: 'tur başında hiçbir soru tamamlanmadı');
    expect(bar().semanticLabel, startsWith('1/3'));

    await tester.tap(
      find
          .ancestor(
            of: find.text(questions.first.correctAnswer),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(
      bar().value,
      closeTo(1 / 3, 1e-9),
      reason: 'cevaplanan soru tamamlanmış sayılır',
    );
    expect(
      bar().semanticLabel,
      contains('1 Doğru'),
      reason: 'doğru sayısı ekran okuyucu özetinde',
    );
  });

  testWidgets('şık çubuğu gölgesizdir', (tester) async {
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deco =
        barOf(tester, question.displayAnswers.first).decoration!
            as BoxDecoration;
    expect(deco.boxShadow, isNull, reason: 'Şahnê: tek gölge birincil düğmede');
  });

  testWidgets('cevap sonrası açıklama Zana sesiyle sunulur', (tester) async {
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
          experience: QuizExperience.learning,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(question.correctAnswer));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 2026-07-26: açıklama başlığı tur içinden kaldırıldı; cevaptan hemen
    // sonra yalnız doğru cevap gösterilir. Açıklamalar sonuç ekranında
    // toplanır (bkz. `_AllExplanationsCard`).
    expect(find.text('Açıklama · Zana'), findsNothing);
    // 2026-08-19: "Doğru cevap" kutusu çoktan seçmeli sorulardan
    // kaldırıldı — doğru şık zaten yeşile dönüp tik alıyordu, kutu aynı
    // bilgiyi ikinci kez söyleyip kıt olan dikey alanı kaplıyordu
    // (uygulama sahibinin bildirimi). Kutu yalnız kelime sıralamada
    // kalır; orada doğru dizilimi açan başka hiçbir şey yok
    // (bkz. `needsAnswerRevealFallback`, `lesson_explanation_test`).
    // Korunan asıl kural DEĞİŞMEDİ: açıklama METNİ tur içinde açılmaz.
    expect(find.text('Doğru cevap'), findsNothing);
  });

  // 2026-09-27: şıkların arkasındaki kilim dokusu kalktı — cevaptan sonra
  // soluklaşan şıkların içinden görünüyor ve okumayı zorlaştırıyordu.
  // 2026-09-29 Şahnê: maskot da kalktı (boş durumda logo işareti var);
  // soru sahnesinde Zana yüzü yok.
  testWidgets('şıklar desensiz tahtaya oturur, sahnede maskot yok', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-answer-board')), findsOneWidget);
    final boardPainters = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('quiz-answer-board')),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((paint) => paint.painter)
        .whereType<KilimPainter>();
    expect(
      boardPainters,
      isEmpty,
      reason: 'Şıkların arkasında kilim dokusu okumayı zorlaştırıyordu.',
    );
    expect(find.byType(RojMascot), findsNothing);

    await tester.tap(find.text(question.correctAnswer));
    await tester.pumpAndSettle();
    expect(find.byType(RojMascot), findsNothing);
  });
}
