import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_board.dart';

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
  testWidgets('cevaplanmamış şıklar nötr yüzey ve border kullanır', (
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

    for (var i = 0; i < question.displayAnswers.length; i++) {
      final answer = question.displayAnswers[i];
      final option = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(answer).first,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = option.decoration! as BoxDecoration;
      // Sahne idle: KOYU kart + şık kimlik rengi kenarlık.
      //
      // Bu beklenti 2026-08-19'da açık tema değerlerinden (#FFFFFF/#F7F4EE,
      // alfa 0.45) çevrildi. Soru ekranı artık uygulama temasından bağımsız
      // olarak `AppTheme.stage` ile koyudur; gerekçe o sabitin belgesinde.
      // Test SİLİNMEDİ çünkü koruduğu şey renk değeri değil kuraldır:
      // cevaplanmamış şık nötr yüzey taşır ve yalnız kenarlığından kimlik
      // alır. Kural sahne altında da geçerli, yalnız değerleri değişti.
      expect(decoration.gradient!.colors, const [
        AppTheme.surfaceHi,
        AppTheme.surface,
      ]);
      final optionColor = AppTheme.answerOptionColors[i % 4];
      expect(
        (decoration.border! as Border).top.color,
        optionColor.withValues(alpha: 0.55),
      );
    }
  });

  testWidgets('cevap sonrası doğru yeşil ve yanlış kırmızı kalır', (
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

    BoxDecoration decorationFor(String answer) {
      final option = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(answer).first,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return option.decoration! as BoxDecoration;
    }

    expect(
      decorationFor(question.correctAnswer).gradient!.colors,
      AppTheme.correctGradient.colors,
    );
    expect(
      decorationFor(wrongAnswer).gradient!.colors,
      AppTheme.wrongGradient.colors,
    );
  });

  testWidgets('Sonraki CTA brand dolgu taşır', (tester) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [repository.questions.first],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    expect(button.style?.backgroundColor?.resolve({}), AppTheme.brand);
  });

  // Eski adı: "aktif soru segmenti brand bekler". Şerit 2026-08-19'da
  // yuvarlak hap segmentlerinden kilim tahtasına (`KilimBoard`) geçti;
  // hap arayan iddia artık boşa düşerdi. Korunan kural aynı: şerit turun
  // KAYDINI tutar — kaçıncı sorudayız ve hangileri doğruydu. Kaydın
  // doğruluğu bileşenin aldığı değerlerden okunur; boyanan pikselden
  // değil, çünkü piksel testte platform yazı tipine/ölçeğine bağlıdır.
  testWidgets('kilim tahtası turun kaydını taşır', (tester) async {
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

    KilimBoard board() => tester.widget<KilimBoard>(
      find.byKey(const ValueKey('quiz-progress-bar')),
    );

    expect(board().total, questions.length);
    expect(board().currentIndex, 0);
    expect(board().results, isEmpty, reason: 'tur başında hiçbir iplik yok');

    await tester.tap(
      find
          .ancestor(
            of: find.text(questions.first.correctAnswer),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(board().results, [
      true,
    ], reason: 'doğru cevap tahtaya altın baklava olarak dokunur');
  });

  testWidgets('şık kartı katı 3D gölge taşımaz', (tester) async {
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

    final firstAnswer = question.displayAnswers.first;
    final option = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(firstAnswer).first,
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final deco = option.decoration as BoxDecoration;
    expect(deco.boxShadow, isNotNull);
    for (final shadow in deco.boxShadow!) {
      expect(shadow.blurRadius, greaterThan(0));
    }
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
}
