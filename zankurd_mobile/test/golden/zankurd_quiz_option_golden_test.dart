import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_quiz_option.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testGoldens('ZankurdQuizOption states dark', (tester) async {
    await tester.pumpWidgetBuilder(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ZankurdQuizOption(label: 'Neutral option text here.', optionLetter: 'A'),
          SizedBox(height: 8),
          ZankurdQuizOption(
              label: 'Selected option text here.', optionLetter: 'B', state: QuizOptionState.selected),
          SizedBox(height: 8),
          ZankurdQuizOption(
              label: 'Correct option text here.', optionLetter: 'C', state: QuizOptionState.correct),
          SizedBox(height: 8),
          ZankurdQuizOption(
              label: 'Wrong option text here.', optionLetter: 'D', state: QuizOptionState.wrong),
        ],
      ),
      wrapper: materialAppWrapper(theme: AppTheme.dark()),
      surfaceSize: const Size(380, 340),
    );
    await screenMatchesGolden(tester, 'zankurd_quiz_option_states_dark');
  });

  testGoldens('ZankurdQuizOption states light', (tester) async {
    await tester.pumpWidgetBuilder(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ZankurdQuizOption(label: 'Neutral option text here.', optionLetter: 'A'),
          SizedBox(height: 8),
          ZankurdQuizOption(
              label: 'Selected option text here.', optionLetter: 'B', state: QuizOptionState.selected),
          SizedBox(height: 8),
          ZankurdQuizOption(
              label: 'Correct option text here.', optionLetter: 'C', state: QuizOptionState.correct),
          SizedBox(height: 8),
          ZankurdQuizOption(
              label: 'Wrong option text here.', optionLetter: 'D', state: QuizOptionState.wrong),
        ],
      ),
      wrapper: materialAppWrapper(theme: AppTheme.light()),
      surfaceSize: const Size(380, 340),
    );
    await screenMatchesGolden(tester, 'zankurd_quiz_option_states_light');
  });
}
