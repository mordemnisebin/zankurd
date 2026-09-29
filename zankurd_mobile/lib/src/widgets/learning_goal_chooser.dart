import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/learning_goal.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

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
    final t = SahneTokens.of(context);
    // Çiplerin dalgası Material atası ister; testlerde ve çipsiz yüzeylerde
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
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          if (!compact) ...[
            const SizedBox(height: SahneSpace.x1),
            Text(
              Tr.forKu(K.learningGoalHint, isKu),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ],
          const SizedBox(height: SahneSpace.x2),
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
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
    // 2026-09-29 Şahnê: seçim rayı çipinin ikonlu çeşidi — 48, M pah;
    // seçili: öğrenme tonu + Halka 2 Zimrût metni, ikon ve söz Zimrût
    // metni. Seçim ekran
    // okuyucuya da söylenir. Seçili değil: Kulis tonu + ikincil metin.
    final t = SahneTokens.of(context);
    final fg = selected ? t.learnTx : t.tx2;
    final shape = selected
        ? SahneShape.withSide(SahneShape.m, t.learnTx, width: SahneRing.r2)
        : SahneShape.withSide(SahneShape.m, t.edge, width: 1);
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SahneTappable(
        shape: shape,
        // Seçili değilken Kulis (`s2`): seçici genelde bir yüzey kartının
        // (Perde) içinde durur; Perde üstünde Perde çip görünmez olur.
        color: selected ? t.learnTint : t.s2,
        onTap: onTap,
        child: ConstrainedBox(
          // 48: erişilebilirlik kılavuzu testinin dokunma alt sınırı.
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    label,
                    style: SahneType.captionStrong.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
