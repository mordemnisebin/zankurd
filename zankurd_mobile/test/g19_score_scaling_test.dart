import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/okunur_boyut.dart';
import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

class _NonLinear extends TextScaler {
  const _NonLinear();
  @override
  double scale(double fontSize) => fontSize * 1.1 + 12.6;
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(14) / 14;
}

void main() {
  setUpAll(loadAppFonts);
  for (final width in [320.0, 375.0, 768.0]) {
    for (final (label, scaler) in const [
      ('130', TextScaler.linear(1.3)),
      ('200', TextScaler.linear(2)),
      ('doğrusal olmayan 200', _NonLinear()),
    ]) {
      testWidgets(
        'G19: $width yüzde $label skor/rütbe küçülmez; eski bekçi 1.15 tavanını doğru kabul ediyordu',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({
            'zankurd.quiz_tutorial.seen': true,
          });
          final repo = freshMockRepository();
          await tester.pumpWidget(
            testShell(
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scaler),
                  child: QuizScreen(
                    repository: repo,
                    enableTimer: false,
                    room: const GameRoom(
                      id: 'g19',
                      name: 'Oda',
                      code: 'G19',
                      category: 'Ziman',
                      status: RoomStatus.active,
                      questionCount: 1,
                      maxPlayers: 4,
                      isCustom: true,
                      hostId: 'h',
                      players: [
                        Player(
                          id: 'user',
                          name: 'Tolhildan Mawal',
                          score: 12345,
                          state: 'Hazır',
                        ),
                        Player(
                          name: 'Rakip Oyuncu',
                          score: 99999,
                          state: 'Hazır',
                        ),
                        Player(name: 'Üçüncü', score: 8765, state: 'Hazır'),
                        Player(name: 'Dördüncü', score: 54321, state: 'Hazır'),
                      ],
                    ),
                    questions: const [
                      QuizQuestion(
                        id: 'g19-question',
                        category: 'Ziman',
                        prompt: 'Silav',
                        promptTr: 'Merhaba',
                        answers: ['A', 'B', 'C', 'D'],
                        correctAnswer: 'A',
                        explanation: '',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('quiz-crowd-rank')))
                .data,
            '#3/4',
          );
          for (final key in [
            'quiz-crowd-rank',
            for (var rank = 1; rank <= 4; rank++) ...[
              'quiz-crowd-score-$rank',
              'quiz-crowd-name-$rank',
            ],
          ]) {
            final finder = find.byKey(ValueKey(key));
            expect(finder, findsOneWidget);
            expect(
              renderedFontSize(tester, finder),
              greaterThanOrEqualTo(scaler.scale(14) - .01),
              reason: key,
            );
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            // Kompakt çipte kısa ad mevcut ellipsis davranışını korur;
            // önemli sıra ve puan hiçbir ölçekte kırpılamaz. Büyük düzende
            // adlar da tam görünür ve semantik etiket her zaman tamdır.
            if (!key.startsWith('quiz-crowd-name-') ||
                scaler.scale(14) > 14 * 1.3) {
              expect(paragraph.didExceedMaxLines, isFalse, reason: key);
            }
          }
          final header = tester.getRect(
            find.byKey(const ValueKey('quiz-crowd-header')),
          );
          expect(header.left, greaterThanOrEqualTo(0));
          expect(header.right, lessThanOrEqualTo(width));
          // Büyüyen kart bütün soru akışını kilitlemez: son şık kaydırılarak erişilir.
          await tester.ensureVisible(find.text('D').last);
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
