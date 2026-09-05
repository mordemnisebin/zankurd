import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';

import 'support/widget_test_helpers.dart';

/// 2026-09-03 simülatör: süresiz günde dersinde tutorial 1/2 şık A'nın
/// üstüne biniyordu. Balon şıkları örtmemeli.
void main() {
  testWidgets('öğrenme turu balonu ilk şıkkın üstüne binmez', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });

    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          experience: QuizExperience.learning,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = find.byType(CoachMarkOverlay);
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.text('Cevabı seç')),
      findsOneWidget,
    );

    final option = tester.getRect(find.byType(QuizOptionTile).first);
    final bubble = tester.getRect(
      find.descendant(of: overlay, matching: find.text('Cevabı seç')),
    );
    expect(
      option.overlaps(bubble),
      isFalse,
      reason: 'tutorial balonu şık A ile kesişmemeli',
    );
  });
}
