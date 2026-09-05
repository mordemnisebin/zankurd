import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/widgets/learning_goal_chooser.dart';

void main() {
  testWidgets('iki amaçtan seçilen değeri bildirir', (tester) async {
    LearningGoal? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningGoalChooser(
            isKu: false,
            selected: null,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Bugün neye odaklanmak istersin?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learning-goal-culture')));
    expect(selected, LearningGoal.discoverCulture);
  });

  testWidgets('Kurmancî metin ve seçili durum erişilebilir görünür', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningGoalChooser(
            isKu: true,
            selected: LearningGoal.learnKurmanci,
            compact: true,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Armanca min'), findsOneWidget);
    expect(find.text('Kurmancî hîn bibim'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('learning-goal-language')))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toString(),
      'Tristate.isTrue',
    );
  });
}
