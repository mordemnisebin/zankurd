import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

import 'support/widget_test_helpers.dart';

const _favoriteQuestion = QuizQuestion(
  id: 'large-text-metadata-favorite',
  category: 'Teknolojî',
  prompt:
      'Ev pirs ji bo kontrolkirina xwendina nivîsa dirêj a pirsê hatiye amadekirin.',
  answers: ['bersiv'],
  correctAnswer: 'bersiv',
  explanation: 'Ravekirina testê.',
  type: QuestionType.fillInBlank,
);

class _FavoritesRepository extends MockZanKurdRepository {
  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async => [
    _favoriteQuestion,
  ];
}

class _RoomConfigRepository extends MockZanKurdRepository {
  int? capturedEntryFee;

  @override
  Future<int> loadCoinBalance() async => 500;

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
  }) async {
    capturedEntryFee = entryFee;
    return super.createOnlineRoom(
      category: category,
      secondsPerQuestion: secondsPerQuestion,
      questionCount: questionCount,
      entryFee: entryFee,
    );
  }
}

const _sizes = <({String name, Size size})>[
  (name: '360x800', size: Size(360, 800)),
  (name: '390x844', size: Size(390, 844)),
];

const _scales = <({String name, double value})>[
  (name: '1.0', value: 1.0),
  (name: '1.3', value: 1.3),
  (name: '2.0', value: 2.0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['tr', 'ku']) {
    for (final viewport in _sizes) {
      for (final scale in _scales) {
        testWidgets(
          'favorites metadata stays inside the card — $locale ${viewport.name} @${scale.name}',
          (tester) async {
            await tester.binding.setSurfaceSize(viewport.size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            tester.platformDispatcher.textScaleFactorTestValue = scale.value;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              testShell(
                child: FavoriteQuestionsScreen(
                  repository: _FavoritesRepository(),
                ),
                languageProvider: locale == 'ku'
                    ? kurmanciLang()
                    : turkishLang(),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'favorites metadata must not produce RenderFlex overflow: '
                  '$locale ${viewport.name} @${scale.name}',
            );

            final categoryLabel = locale == 'ku' ? 'Teknolojî' : 'Teknoloji';
            final typeLabel = locale == 'ku' ? 'Tijîkirin' : 'Boşluk Doldurma';
            for (final label in [categoryLabel, typeLabel]) {
              final badge = find.text(label);
              expect(badge, findsOneWidget, reason: '$label badge missing');
              final badgeRect = tester.getRect(badge);
              expect(badgeRect.left, greaterThanOrEqualTo(0));
              expect(badgeRect.right, lessThanOrEqualTo(viewport.size.width));
              final badgeText = tester.widget<Text>(badge);
              expect(badgeText.maxLines, isNull);
              expect(badgeText.overflow, isNull);
            }

            final removeTooltip = locale == 'ku' ? 'Rake' : 'Kaldır';
            final remove = find.byTooltip(removeTooltip);
            expect(remove, findsOneWidget);
            expect(
              tester
                  .getSemantics(remove)
                  .getSemanticsData()
                  .hasAction(ui.SemanticsAction.tap),
              isTrue,
            );
            expect(find.byIcon(AppIcons.play), findsOneWidget);
            expect(
              find.text(_favoriteQuestion.prompt),
              findsOneWidget,
              reason: 'favorite prompt must remain available to the card',
            );
          },
        );

        testWidgets(
          'custom room fee chips stay readable — $locale ${viewport.name} @${scale.name}',
          (tester) async {
            await tester.binding.setSurfaceSize(viewport.size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            tester.platformDispatcher.textScaleFactorTestValue = scale.value;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              testShell(
                child: PlayHubScreen(repository: _RoomConfigRepository()),
                languageProvider: locale == 'ku'
                    ? kurmanciLang()
                    : turkishLang(),
              ),
            );
            await tester.pumpAndSettle();

            final createRoom = find.byKey(
              const ValueKey('play-hub-create-room'),
            );
            if (createRoom.evaluate().isEmpty) {
              debugPrint(
                'NOT_AVAILABLE custom room entry: '
                '$locale ${viewport.name} @${scale.name}',
              );
              return;
            }
            await tester.ensureVisible(createRoom);
            await tester.pumpAndSettle();
            await tester.tap(createRoom);
            await tester.pumpAndSettle();

            final feeLabels = <String>[
              locale == 'ku' ? 'Bêpere (0)' : 'Ücretsiz (0)',
              for (final fee in [25, 50, 100])
                '$fee ${locale == 'ku' ? 'Zêr' : 'Coin'}',
            ];
            for (final label in feeLabels) {
              expect(
                find.text(label),
                findsOneWidget,
                reason: '$label missing',
              );
            }
            for (final fee in GameRoom.allowedEntryFees) {
              final chip = find.byKey(ValueKey('custom-room-fee-$fee'));
              expect(chip, findsOneWidget, reason: '$fee chip missing');
              await tester.ensureVisible(chip);
              await tester.pump();
              final chipRect = tester.getRect(chip);
              expect(chipRect.left, greaterThanOrEqualTo(0));
              expect(chipRect.right, lessThanOrEqualTo(viewport.size.width));
              expect(chipRect.top, greaterThanOrEqualTo(0));
              expect(chipRect.bottom, lessThanOrEqualTo(viewport.size.height));
            }

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'custom room fee chip must not produce RenderFlex overflow: '
                  '$locale ${viewport.name} @${scale.name}',
            );
          },
        );
      }
    }
  }

  testWidgets('custom room selected fee reaches the room config unchanged', (
    tester,
  ) async {
    final repository = _RoomConfigRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();

    final fee = find.byKey(const ValueKey('custom-room-fee-100'));
    await tester.ensureVisible(fee);
    await tester.tap(fee);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(fee).getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );

    final openRoom = find.text('Odayı Aç');
    await tester.ensureVisible(openRoom);
    await tester.pump();
    await tester.tap(openRoom);
    await tester.pumpAndSettle();

    expect(repository.capturedEntryFee, 100);
    expect(tester.takeException(), isNull);
  });
}
