import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Visual states for [ZankurdQuizOption].
enum QuizOptionState {
  /// Default / untouched.
  neutral,

  /// Currently selected (not yet submitted).
  selected,

  /// Submitted and correct.
  correct,

  /// Submitted and incorrect.
  wrong,
}

/// Static quiz option card — visual only, no quiz logic.
///
/// Displays an option letter badge and a label text.
/// States are purely visual; correct/wrong colours use
/// [AppTheme.correct] / [AppTheme.wrong] tokens.
class ZankurdQuizOption extends StatelessWidget {
  const ZankurdQuizOption({
    super.key,
    required this.label,
    required this.optionLetter,
    this.state = QuizOptionState.neutral,
    this.onTap,
  });

  /// The option text (e.g. answer body).
  final String label;

  /// Single letter identifier (A, B, C, D).
  final String optionLetter;

  /// Current visual state.
  final QuizOptionState state;

  /// Tap callback. When `null` the option is non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color textColor) = switch (state) {
      QuizOptionState.neutral => (
        AppTheme.surfaceHiOf(context),
        AppTheme.borderOf(context),
        AppTheme.textPrimaryOf(context),
      ),
      QuizOptionState.selected => (
        AppTheme.accent.withValues(alpha: 0.12),
        AppTheme.accent,
        AppTheme.accent,
      ),
      QuizOptionState.correct => (
        AppTheme.correct.withValues(alpha: 0.12),
        AppTheme.correct,
        AppTheme.correct,
      ),
      QuizOptionState.wrong => (
        AppTheme.wrong.withValues(alpha: 0.12),
        AppTheme.wrong,
        AppTheme.wrong,
      ),
    };

    final card = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          // Option letter badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: state == QuizOptionState.neutral
                  ? AppTheme.surfaceColor(context)
                  : border.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: border, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(
              optionLetter,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Option text
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: textColor),
            ),
          ),
          // State icon (correct / wrong)
          if (state == QuizOptionState.correct)
            Icon(
              AppTheme.correct == textColor
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              color: textColor,
              size: 22,
            )
          else if (state == QuizOptionState.wrong)
            Icon(Icons.cancel_outlined, color: textColor, size: 22),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
