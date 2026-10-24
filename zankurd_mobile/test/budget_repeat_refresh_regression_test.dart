import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/widgets/todays_review_card.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    freshMockRepository();
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });
  tearDown(() {
    freshMockRepository();
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testShell(child: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('home shows word-only due repeats', (tester) async {
    final words = await WordListStore.load();
    await words.add('rojbas');
    await pump(tester, HomeScreen(repository: MockZanKurdRepository()));
    expect(find.byKey(const ValueKey('home-review-row')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lesson return refreshes the same review card plan', (
    tester,
  ) async {
    final words = await WordListStore.load();
    await pump(tester, LearningScreen(repository: MockZanKurdRepository()));
    final cardState = tester.state(find.byType(TodaysReviewCard));
    expect(find.byKey(const ValueKey('todays-review-card')), findsNothing);

    final lesson = find.byKey(const ValueKey('learning-route-stop-alphabet_1'));
    await tester.ensureVisible(lesson);
    await tester.tap(lesson);
    await tester.pumpAndSettle();
    expect(find.byType(LessonDetailScreen), findsOneWidget);
    // A saved word becomes due while the lesson route is open.
    await words.add('rojbas');
    Navigator.of(tester.element(find.byType(LessonDetailScreen))).pop();
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(TodaysReviewCard)), same(cardState));
    expect(find.text('Tekrar · bugün 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
