import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/auth_social_buttons.dart';

import 'support/okunur_boyut.dart';
import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const t7Question = QuizQuestion(
  id: 't7',
  category: 'Ziman',
  prompt: 'Yek + yek?',
  promptTr: 'Bir + bir?',
  answers: ['2', '3', '4', '5'],
  correctAnswer: '2',
  explanation: '',
);

GameRoom t7Room({int score = 99999, int streak = 5}) => GameRoom(
  id: 't7-room',
  name: 'T7',
  code: 'T7',
  category: 'Ziman',
  status: RoomStatus.active,
  questionCount: 2,
  players: [
    Player(id: 'user', name: 'Ali', score: score, streak: streak, state: ''),
    const Player(id: 'other', name: 'Bero', score: 12345, streak: 5, state: ''),
  ],
);

void main() {
  setUpAll(loadAppFonts);
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    }),
  );

  for (final size in const [
    Size(320, 874),
    Size(375, 874),
    Size(402, 874),
    Size(800, 600),
  ]) {
    final width = size.width;
    for (final scale in [1.0, 1.3]) {
      for (final ku in [false, true]) {
        testWidgets(
          'U13 $width×${size.height} × $scale KU=$ku: beş haneli puan ve ×5 okunur',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              testShell(
                languageProvider: ku ? kurmanciLang() : null,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: QuizScreen(
                      repository: freshMockRepository(),
                      room: t7Room(),
                      questions: const [t7Question, t7Question],
                      is1v1: true,
                      enableTimer: false,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);
            for (final key in ['duel-self-score', 'duel-opponent-score']) {
              final finder = find.byKey(ValueKey(key));
              expect(
                renderedFontSize(tester, finder),
                greaterThanOrEqualTo(14 * scale - .01),
              );
              expect(
                tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
                isFalse,
              );
              final rect = tester.getRect(finder);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
            }
            expect(find.text('99.999'), findsOneWidget);
            expect(find.text('12.345'), findsOneWidget);
            expect(find.text('×5'), findsNWidgets(2));
            final question = find.text(ku ? 'Yek + yek?' : 'Bir + bir?');
            final top = tester.getTopLeft(question);
            await tester.pump(const Duration(seconds: 1));
            expect(tester.getTopLeft(question), top);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }

  testWidgets('T4 hesap bağlamada Apple ve Google aynı devam et fiili', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: AuthSocialButtons(
            linking: true,
            showApple: true,
            onApple: () {},
            onGoogle: () {},
          ),
        ),
      ),
    );
    expect(find.text('Apple ile devam et'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('Google ile bağla'), findsNothing);
  });
}
