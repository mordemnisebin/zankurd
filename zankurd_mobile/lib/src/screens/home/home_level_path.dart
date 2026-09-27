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

Color homePathLevelColor(int number) => AppTheme.culturalBrandBg;

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
    final categoryAccent = CategoryVisuals.color(category);
    final categoryAccentOnSurface = AppColors.readableAccent(
      context,
      categoryAccent,
    );
    const radius = AppRadius.card;

    final label = nextTitle == null
        ? Tr.forKu(K.homeLearningPath, isKu)
        : Tr.forKu(K.homePathNext, isKu, {'name': nextTitle});

    return Material(
      color: Colors.transparent,
      child: Padding(
        // 2026-09-25: bu blok sayfa zemininde havada duruyordu; hemen
        // üstündeki "Kurmancî hîn bibe" satırıyla aynı kalıbı (ikon + iki
        // satır metin + ok) paylaştığı için ikisi de "hın bibe" girdisi
        // gibi görünüyor, hangisinin yol olduğu anlaşılmıyordu. Yol bir
        // nesnedir: düğüm şeridi, kilit/rozet durumu ve "Hemû mijar" eylemi
        // taşır. Ona yüzey verilerek iki satır birbirinden ayrılıyor ve
        // bölüm başlığı altındaki hiyerarşi okunuyor.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
          0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: AppTheme.cardShadow(context),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Column(
            key: const ValueKey('home-learning-path-route'),
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
                              color: categoryAccentOnSurface,
                              onColor: categoryAccentOnSurface,
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
                                      color: AppTheme.textMutedColor(context),
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
                              color: AppTheme.textMutedColor(context),
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
                                    // 2026-09-25 düzeltmesi: bağlantı çizgisi
                                    // `bottom: 18` ile aşağı itiliyordu ve
                                    // 40pt düğümlerin merkezinden ~7pt aşağıda
                                    // duruyordu — yol hattı kırık görünüyordu.
                                    // Satır `CrossAxisAlignment.center` olduğu
                                    // için çizgi kendi hizasında düğüm
                                    // merkezine gelir; düğüm boyutu değişse de
                                    // hizalama bozulmaz.
                                    color: played.contains(levels[i - 1].number)
                                        ? AppTheme.culturalBrandBg
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      foregroundColor: AppTheme.culturalBrandBg,
                    ),
                    child: Text(
                      Tr.forKu(K.homePathBrowse, isKu),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.readableAccent(
                          context,
                          AppTheme.culturalBrandBg,
                        ),
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
    const brand = AppTheme.culturalBrandBg;
    final brandOnSurface = AppColors.readableAccent(context, brand);
    final fill = played
        ? brand
        : locked
        ? AppTheme.surfaceHiColor(context)
        : isNext
        ? AppColors.iconTileBg(context, brand)
        : AppTheme.surfaceColor(context);
    final icon = locked
        ? AppIcons.lock
        : played
        ? AppIcons.circleCheck
        : null;

    return Column(
      children: [
        Container(
          key: ValueKey('home-path-node-${level.number}'),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isNext && !locked
                  ? brandOnSurface
                  : AppTheme.borderColor(context),
              width: isNext && !locked ? 2 : 1,
            ),
          ),
          child: icon == null
              ? Text(
                  '${level.number}',
                  style: AppTypography.caption.copyWith(
                    color: isNext
                        ? brandOnSurface
                        : AppTheme.textMutedColor(context),
                    fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  ),
                )
              : Icon(
                  icon,
                  size: 15,
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
                ? brandOnSurface
                : AppTheme.textMutedColor(context),
            fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
