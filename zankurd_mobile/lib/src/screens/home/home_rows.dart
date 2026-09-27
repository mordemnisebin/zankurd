import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';

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
