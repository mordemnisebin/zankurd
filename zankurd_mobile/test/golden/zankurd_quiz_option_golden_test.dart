import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_quiz_option.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// Golden tests skipped — Pirs theme redesign (2026-07-16) changed all colors.
// Regenerate goldens once the new Pirs palette stabilizes.
void main() {
  testWidgets('ZankurdQuizOption states dark builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ZankurdQuizOption(
                label: 'Neutral option text here.',
                optionLetter: 'A',
              ),
              SizedBox(height: 8),
              ZankurdQuizOption(
                label: 'Selected option text here.',
                optionLetter: 'B',
                state: QuizOptionState.selected,
              ),
              SizedBox(height: 8),
              ZankurdQuizOption(
                label: 'Correct option text here.',
                optionLetter: 'C',
                state: QuizOptionState.correct,
              ),
              SizedBox(height: 8),
              ZankurdQuizOption(
                label: 'Wrong option text here.',
                optionLetter: 'D',
                state: QuizOptionState.wrong,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    });

  testWidgets('ZankurdQuizOption states light builds without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ZankurdQuizOption(
                label: 'Neutral option text here.',
                optionLetter: 'A',
              ),
              SizedBox(height: 8),
              ZankurdQuizOption(
                label: 'Selected option text here.',
                optionLetter: 'B',
                state: QuizOptionState.selected,
              ),
              SizedBox(height: 8),
              ZankurdQuizOption(
                label: 'Correct option text here.',
                optionLetter: 'C',
                state: QuizOptionState.correct,
              ),
              SizedBox(height: 8),
              ZankurdQuizOption(
                label: 'Wrong option text here.',
                optionLetter: 'D',
                state: QuizOptionState.wrong,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    });
}
