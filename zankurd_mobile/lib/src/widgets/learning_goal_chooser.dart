import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/learning_goal.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class LearningGoalChooser extends StatelessWidget {
  const LearningGoalChooser({
    required this.isKu,
    required this.selected,
    required this.onSelected,
    this.compact = false,
    super.key,
  });

  final bool isKu;
  final LearningGoal? selected;
  final ValueChanged<LearningGoal> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // ChoiceChip Material atası ister; testlerde ve chipsiz yüzeylerde
    // patlamaması için şeffaf Material ile sarıldı.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            compact
                ? Tr.forKu(K.learningGoalTitleCompact, isKu)
                : Tr.forKu(K.learningGoalTitle, isKu),
            style: AppTypography.subtitle.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 3),
            Text(
              Tr.forKu(K.learningGoalHint, isKu),
              style: AppTypography.caption.copyWith(
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _GoalChoice(
                key: const ValueKey('learning-goal-language'),
                icon: AppIcons.language,
                label: Tr.forKu(K.learningGoalLearn, isKu),
                selected: selected == LearningGoal.learnKurmanci,
                onTap: () => onSelected(LearningGoal.learnKurmanci),
              ),
              _GoalChoice(
                key: const ValueKey('learning-goal-culture'),
                icon: AppIcons.bookOpen,
                label: Tr.forKu(K.learningGoalCulture, isKu),
                selected: selected == LearningGoal.discoverCulture,
                onTap: () => onSelected(LearningGoal.discoverCulture),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalChoice extends StatelessWidget {
  const _GoalChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.playGreen
        : AppTheme.textMutedColor(context);
    return Semantics(
      selected: selected,
      button: true,
      child: ChoiceChip(
        avatar: Icon(icon, size: 17, color: color),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
