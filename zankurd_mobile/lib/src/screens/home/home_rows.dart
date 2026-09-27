import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/percent_format.dart';

/// Home üzerindeki ikincil eylemler için düz satır.
///
/// Ana günlük görev ve öğrenme rotası görsel omurgayı taşır. Bu satır ise
/// ikincil gezinme hedeflerini ayrı ayrı "kart" gibi yükseltmeden erişilebilir
/// ve dokunulabilir tutar.
class HomeSupportRow extends StatelessWidget {
  const HomeSupportRow({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticValue,
    this.surfaceKey,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticValue;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: subtitle == null ? title : '$title. $subtitle',
      value: semanticValue,
      excludeSemantics: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          key: surfaceKey,
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.iconTileBg(context, accent),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: AppColors.readableAccent(context, accent),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subtitle.copyWith(
                              fontSize: 15,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 12.5,
                                color: AppTheme.textSubColor(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    trailing ??
                        Icon(
                          AppIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMutedColor(context),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Kaldığın yer" — oyuncunun ilerlediği kategoriler, ilerleme çubuğuyla.
///
/// Hiç ilerleme yokken bölüm çizilmez. Başlanmış kategoriler Home'un ana
/// rotasının altında düz destek satırlarıdır; ayrı kartlar oluşturmaz.
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    required this.isKu,
    required this.entries,
    this.onOpenCategory,
    super.key,
  });

  final bool isKu;
  final List<CategoryProgress> entries;
  final ValueChanged<String>? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final started = entries.where((e) => e.ratio > 0).toList();
    if (started.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-continue-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: 2),
          child: Text(
            Tr.forKu(K.kaldiginYer, isKu),
            style: AppTypography.heading2.copyWith(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        for (var i = 0; i < started.length; i++) ...[
          HomeSupportRow(
            key: ValueKey('home-continue-row-${started[i].category}'),
            icon: CategoryVisuals.icon(started[i].category),
            accent: CategoryVisuals.color(started[i].category),
            title: CategoryNames.localized(started[i].category, isKu),
            subtitle: Tr.forKu(K.pPDogru, isKu, {
              'p0': '${started[i].correct}',
              'p1': '${started[i].threshold}',
            }),
            semanticValue: context.percentRatio(started[i].ratio),
            onTap: onOpenCategory == null
                ? null
                : () => onOpenCategory!(started[i].category),
            trailing: ExcludeSemantics(
              child: SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.percentRatio(started[i].ratio),
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: started[i].ratio,
                        minHeight: 4,
                        backgroundColor: AppTheme.borderColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CategoryVisuals.color(started[i].category),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i != started.length - 1)
            Divider(
              height: 1,
              indent: 46,
              color: AppTheme.borderColor(context).withValues(alpha: 0.65),
            ),
        ],
      ],
    );
  }
}

/// Bir kategorideki ustalık ilerlemesi (MasteryStore verisinden türetilir).
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.correct,
    required this.threshold,
  });

  final String category;
  final int correct;
  final int threshold;

  double get ratio =>
      threshold <= 0 ? 0 : (correct / threshold).clamp(0.0, 1.0);
}
