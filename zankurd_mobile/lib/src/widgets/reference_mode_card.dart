import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Referans ZanKurd sürümündeki kompakt oyun satırının açık-tema yorumu.
///
/// Yalnızca sunum yapar; oyun ve yönlendirme davranışı [onTap] üzerinden
/// mevcut ekran sahibinde kalır.
class ReferenceModeCard extends StatelessWidget {
  const ReferenceModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.progress,
    this.loading = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final double? progress;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final foreground = AppTheme.textPrimaryColor(context);
    final secondary = AppTheme.textSubColor(context);
    final normalizedProgress = progress?.clamp(0.0, 1.0);

    return Semantics(
      button: true,
      enabled: !loading,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: AppTheme.cardDecoration(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: accent.withValues(alpha: 0.28)),
                    ),
                    child: Icon(icon, color: accent, size: 25),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (normalizedProgress != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: normalizedProgress,
                              minHeight: 5,
                              color: accent,
                              backgroundColor: accent.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (loading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: accent,
                      ),
                    )
                  else
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 19,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
