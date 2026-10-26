import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
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

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String lang = 'tr',
  }) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: screen,
        languageProvider: LanguageProvider(initialLang: lang),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final lang in ['tr', 'ku']) {
    for (final count in [1, 2]) {
      testWidgets('home labels $count due words as items in $lang', (
        tester,
      ) async {
        final words = await WordListStore.load();
        await words.add('rojbas');
        if (count == 2) await words.add('spas');
        await pump(
          tester,
          HomeScreen(repository: MockZanKurdRepository()),
          lang: lang,
        );
        final row = find.byKey(const ValueKey('home-review-row'));
        expect(row, findsOneWidget);
        final text = lang == 'tr'
            ? '$count öğe seni bekliyor'
            : '$count tişt li benda te ${count == 1 ? 'ye' : 'ne'}';
        expect(
          find.descendant(of: row, matching: find.text(text)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

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
