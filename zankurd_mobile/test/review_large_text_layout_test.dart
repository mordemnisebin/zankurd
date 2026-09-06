import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';

const _room = GameRoom(
  name: 'Oda',
  code: 'ZK-4C',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
  questionCount: 2,
);

const _records = [
  AnswerRecord(
    id: 'review-large-text-wrong',
    category: 'Ziman',
    prompt:
        'Ev pirs ji bo ceribandina xwendina nivîsa dirêj hatiye amadekirin.',
    answers: ['Rast', 'Şaş'],
    correctAnswer: 'Rast',
    selectedAnswer: 'Şaş',
    explanation: 'Ravekirina dirêj a pirsê ji bo testê.',
  ),
  AnswerRecord(
    id: 'review-large-text-correct',
    category: 'Ziman',
    prompt: 'Pirsên din jî divê di nav layoutê de bêne gihîştin.',
    answers: ['Rast', 'Şaş'],
    correctAnswer: 'Rast',
    selectedAnswer: 'Rast',
    explanation: 'Ravekirina duyemîn.',
  ),
  AnswerRecord(
    id: 'review-large-text-blank',
    category: 'Ziman',
    prompt: 'Ev pirs bê bersiv maye.',
    answers: ['Rast', 'Şaş'],
    correctAnswer: 'Rast',
    selectedAnswer: null,
    explanation: 'Ravekirina pirsê.',
  ),
];

enum _ReviewState { list, flashcardFront, flashcardBack }

const _viewports = <({String name, Size size})>[
  (name: '320x568', size: Size(320, 568)),
  (name: '360x800', size: Size(360, 800)),
  (name: '390x844', size: Size(390, 844)),
];

const _scales = <({String name, double value})>[
  (name: '1.0', value: 1.0),
  (name: '1.3', value: 1.3),
  (name: '2.0', value: 2.0),
];

Widget _shell(Widget child, String locale) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider()..setLang(locale),
    child: MaterialApp(home: child),
  );
}

List<Object> _takeExceptions(WidgetTester tester) {
  final exceptions = <Object>[];
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception!);
  }
  return exceptions;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['tr', 'ku']) {
    for (final viewport in _viewports) {
      for (final scale in _scales) {
        for (final state in _ReviewState.values) {
          testWidgets('Review ${state.name} has no large-text overflow — '
              '$locale ${viewport.name} @${scale.name}', (tester) async {
            await tester.binding.setSurfaceSize(viewport.size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            tester.platformDispatcher.textScaleFactorTestValue = scale.value;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _shell(
                const ReviewScreen(records: _records, room: _room),
                locale,
              ),
            );
            await tester.pumpAndSettle();

            if (state == _ReviewState.list) {
              final scrollable = find.byType(Scrollable).first;
              final status = find.text(locale == 'ku' ? 'ŞAŞ' : 'YANLIŞ');
              await tester.scrollUntilVisible(
                status,
                200,
                scrollable: scrollable,
              );
              expect(status, findsOneWidget);
              expect(
                find.text(locale == 'ku' ? 'Pirs 1' : 'Soru 1'),
                findsOneWidget,
              );
              for (final label in [
                locale == 'ku' ? 'RAST' : 'DOĞRU',
                locale == 'ku' ? 'Vala ma' : 'BOŞ BIRAKILDI',
              ]) {
                final statusLabel = find.text(label);
                await tester.scrollUntilVisible(
                  statusLabel,
                  200,
                  scrollable: scrollable,
                );
                expect(statusLabel, findsOneWidget);
              }
            } else {
              final modeLabel = locale == 'ku'
                  ? 'Kartên Hînbûnê'
                  : 'Hafıza Kartları';
              await tester.ensureVisible(find.text(modeLabel));
              await tester.tap(find.text(modeLabel));
              await tester.pumpAndSettle();

              final card = find.byKey(const ValueKey('review-flashcard'));
              await tester.scrollUntilVisible(
                card,
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              if (state == _ReviewState.flashcardBack) {
                await tester.tap(card);
                await tester.pumpAndSettle();
              }

              final data = tester.getSemantics(card).getSemanticsData();
              expect(data.flagsCollection.isButton, isTrue);
              expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
            }

            final exceptions = _takeExceptions(tester);
            expect(
              exceptions,
              isEmpty,
              reason:
                  'Review must not emit RenderFlex overflow: '
                  '$locale ${viewport.name} @${scale.name} ${state.name}\n'
                  '${exceptions.join('\n')}',
            );
          });
        }
      }
    }
  }
}
