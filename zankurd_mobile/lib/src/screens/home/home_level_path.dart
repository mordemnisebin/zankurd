import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/quiz_level.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/kilim_motifs.dart';
import 'home_rows.dart';

/// Başlanmış kategorilerden ilki; yoksa listenin ilki.
String homePathFocusCategory({
  required List<CategoryProgress> started,
  required List<String> categories,
}) {
  if (started.isNotEmpty) return started.first.category;
  if (categories.isNotEmpty) return categories.first;
  return 'Ziman';
}

bool isHomePathLevelUnlocked(int number, Set<int> played) {
  if (number <= 1) return true;
  return played.contains(number - 1);
}

int? homePathNextLevel(List<int> numbers, Set<int> played) {
  for (final number in numbers) {
    if (!played.contains(number)) return number;
  }
  return null;
}

Color homePathLevelColor(int number) => switch (number) {
  1 => AppTheme.correct,
  2 => AppTheme.playCyan,
  3 => AppTheme.gold,
  4 => AppTheme.primaryGradientStart,
  _ => AppTheme.violet,
};

/// Ana sayfadaki kompakt seviye yolu — LevelScreen haritasının önizlemesi.
class HomeLevelPath extends StatelessWidget {
  const HomeLevelPath({
    required this.category,
    required this.levels,
    required this.played,
    required this.isKu,
    required this.onOpen,
    this.onBrowse,
    super.key,
  });

  final String category;
  final List<QuizLevel> levels;
  final Set<int> played;
  final bool isKu;
  final VoidCallback onOpen;

  /// Konu listesi. Ayrı bir "Konu seç" kartı yok; keşif yolun içinden.
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final next = homePathNextLevel([
      for (final level in levels) level.number,
    ], played);
    final nextTitle = () {
      for (final level in levels) {
        if (level.number == next) {
          return LevelNames.localized(level.title, isKu);
        }
      }
      return null;
    }();
    final accent = CategoryVisuals.color(category);
    final accentOnSurface = AppColors.readableAccent(context, accent);
    const radius = 18.0;

    final label = nextTitle == null
        ? Tr.forKu(K.homeLearningPath, isKu)
        : Tr.forKu(K.homePathNext, isKu, {'name': nextTitle});

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.08),
            AppTheme.surfaceColor(context),
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: accentOnSurface.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                key: const ValueKey('home-lessons-row'),
                button: true,
                label: label,
                onTap: onOpen,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(radius),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryEmblem(
                              icon: CategoryVisuals.icon(category),
                              color: accentOnSurface,
                              onColor: accentOnSurface,
                              size: 36,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Tr.forKu(K.homePathTrack, isKu, {
                                      'category': CategoryNames.localized(
                                        category,
                                        isKu,
                                      ),
                                    }),
                                    style: AppTypography.caption.copyWith(
                                      color: accentOnSurface,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    nextTitle == null
                                        ? Tr.forKu(K.homeLearningPath, isKu)
                                        : Tr.forKu(K.homePathNext, isKu, {
                                            'name': nextTitle,
                                          }),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.subtitle.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimaryColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              AppIcons.chevronRight,
                              color: accentOnSurface,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            for (var i = 0; i < levels.length; i++) ...[
                              if (i > 0)
                                Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.only(bottom: 18),
                                    color: played.contains(levels[i - 1].number)
                                        ? homePathLevelColor(levels[i].number)
                                        : AppTheme.borderColor(context),
                                  ),
                                ),
                              _HomePathNode(
                                level: levels[i],
                                played: played.contains(levels[i].number),
                                isNext: levels[i].number == next,
                                locked: !isHomePathLevelUnlocked(
                                  levels[i].number,
                                  played,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onBrowse != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('home-browse-categories-row'),
                    onPressed: onBrowse,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(44, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: accentOnSurface,
                    ),
                    child: Text(
                      Tr.forKu(K.homePathBrowse, isKu),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentOnSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePathNode extends StatelessWidget {
  const _HomePathNode({
    required this.level,
    required this.played,
    required this.isNext,
    required this.locked,
  });

  final QuizLevel level;
  final bool played;
  final bool isNext;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = homePathLevelColor(level.number);
    final fill = locked
        ? AppTheme.surfaceHiColor(context)
        : played || isNext
        ? color
        : AppColors.iconTileBg(context, color);
    final icon = locked
        ? AppIcons.lock
        : played
        ? AppIcons.circleCheck
        : isNext
        ? AppIcons.play
        : null;

    return Column(
      children: [
        Container(
          key: ValueKey('home-path-node-${level.number}'),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(
              color: isNext && !locked ? Colors.white : color,
              width: isNext && !locked ? 3 : 1.5,
            ),
            boxShadow: isNext && !locked
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: icon == null
              ? const SizedBox.shrink()
              : Icon(
                  icon,
                  size: isNext ? 16 : 15,
                  color: locked
                      ? AppTheme.textMutedColor(context)
                      : Colors.white,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          '${level.number}',
          style: AppTypography.caption.copyWith(
            color: isNext && !locked
                ? AppColors.readableAccent(context, color)
                : AppTheme.textMutedColor(context),
            fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
