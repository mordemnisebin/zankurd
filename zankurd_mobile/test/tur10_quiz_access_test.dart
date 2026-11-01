// Tur 10 / ekran 030 ve yazılı cevap bekçisi.
// Kusur 1: büyük yazıda (2.35x) süreli sorunun C/D şıkları kaydırma olmadan
// görünmüyordu ve kaydırılabildiğine dair hiçbir işaret yoktu; sessizdi çünkü
// testler yalnız normal ölçekte "sığar" kuralını sınıyordu. Şimdi sığmayan
// şıklarda alt kenarda ok ipucu çıkar, normal ölçekte sahne ölçüsü değişmez.
// Kusur 2: yazılı (boşluk doldurma) cevabın gönderimi uçtan uca
// sınanmamıştı; klavye açıkken düğme/IME ile sonuca gittiği ve süre dolunca
// taslağın doğru sayılmadığı burada korunur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const _written = QuizQuestion(
  id: 'tur10-written',
  category: 'Ziman',
  prompt: 'Ez ___ dixwînim.',
  answers: ['pirtûk'],
  correctAnswer: 'pirtûk',
  explanation: '',
  type: QuestionType.fillInBlank,
);
// Tur 10 / 030 karesindeki mevcut ziman_x_0054 banka metni.
const _choice = QuizQuestion(
  id: 'tur10-choice',
  category: 'Ziman',
  prompt: 'Heywanê çolê yê ku bi kerî digere û dijberê pez e, çi ye?',
  answers: ['Hirç', 'Rovî', 'Gur', 'Kew'],
  correctAnswer: 'Gur',
  explanation: '',
);

void main() {
  setUpAll(loadAppFonts);
  Future<void> pumpQuiz(
    WidgetTester tester,
    QuizQuestion q, {
    double scale = 1,
    int seconds = 60,
  }) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 20);
    tester.view.viewPadding = const FakeViewPadding(top: 20);
    addTearDown(tester.view.reset);
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        languageProvider: kurmanciLang(),
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: QuizScreen(
              repository: repository,
              room: repository.createRoom().copyWith(
                secondsPerQuestion: seconds,
              ),
              questions: [q],
              enableTimer: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final scale in [1.0, 2.35]) {
    testWidgets('süreli 375x667 @$scale seçenek erişimi ve kaydırma ipucu', (
      tester,
    ) async {
      await pumpQuiz(tester, _choice, scale: scale);
      final scroll = find.byKey(const ValueKey('quiz-portrait-scroll'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      final hint = find.byKey(const ValueKey('sahne-stage-scroll-hint'));
      if (scale == 1) {
        expect(position.maxScrollExtent, 0);
        expect(hint, findsNothing);
      } else {
        expect(position.maxScrollExtent, greaterThan(0));
        expect(hint, findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(QuizOptionTile).last,
          200,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(hint, findsNothing);
      }
      final last = find.byType(QuizOptionTile).last;
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getRect(scroll).bottom),
      );
      await tester.tap(last);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('quiz-next-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final ime in [false, true]) {
    testWidgets(
      'yazılı cevap açık klavyeyle ${ime ? "IME" : "düğme"} üzerinden sonuca gider',
      (tester) async {
        await pumpQuiz(tester, _written);
        final input = find.byKey(const ValueKey('fill-in-blank-input'));
        await tester.enterText(input, 'pirtk');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();
        final field = tester.widget<EditableText>(find.byType(EditableText));
        field.controller.selection = const TextSelection.collapsed(offset: 4);
        final letter = find.byKey(const ValueKey('fill-in-blank-diacritic-û'));
        await tester.ensureVisible(letter);
        await tester.pump(const Duration(milliseconds: 300));
        expect(letter.hitTestable(), findsOneWidget);
        await tester.tap(letter);
        await tester.pump();
        expect(field.controller.text, 'pirtûk');
        expect(tester.testTextInput.isVisible, isTrue);
        if (ime) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          final submit = find.byKey(const ValueKey('fill-in-blank-submit'));
          await tester.ensureVisible(submit);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.getRect(submit).bottom, lessThanOrEqualTo(667 - 280));
          expect(submit.hitTestable(), findsOneWidget);
          await tester.tap(submit);
        }
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('fill-in-blank-verdict-correct')),
          findsOneWidget,
        );
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
        await tester.pumpAndSettle();
        final result = tester.widget<QuizResultScreen>(
          find.byType(QuizResultScreen),
        );
        expect(result.answerRecords.single.selectedAnswer, 'pirtûk');
        expect(result.answerRecords.single.isCorrect, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('yazılı cevap gönderilmeden süre dolarsa taslak doğru sayılmaz', (
    tester,
  ) async {
    await pumpQuiz(tester, _written, seconds: 3);
    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      'pirtûk',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump(const Duration(seconds: 4));
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fill-in-blank-submit')), findsNothing);
    expect(
      find.byKey(const ValueKey('fill-in-blank-verdict-correct')),
      findsNothing,
    );
    expect(
      tester
          .widget<SahneField>(find.byKey(const ValueKey('fill-in-blank-input')))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
    await tester.pumpAndSettle();
    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.answerRecords.single.selectedAnswer, 'TIMEOUT');
    expect(result.answerRecords.single.isCorrect, isFalse);
    expect(tester.takeException(), isNull);
  });
}
