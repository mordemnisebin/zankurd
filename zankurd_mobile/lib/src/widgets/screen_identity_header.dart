import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kilim_pattern_painter.dart';

/// İkincil ekranların ortak kimlik kartı.
///
/// Ana sekmelerdeki (profil mor, xwendin camgöbeği, pêşbaz altın) imza dilini
/// taşır: accent gradyan, kilim filigranı, ikon rozeti, tema-aware gölge.
/// Davranış / route değişmez — yalnızca sunum.
class ScreenIdentityHeader extends StatelessWidget {
  const ScreenIdentityHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  /// Daha alçak kart (liste üstü şerit).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final foreground = isLight
        ? AppTheme.textPrimaryColor(context)
        : Colors.white;
    final secondary = isLight
        ? AppTheme.textSubColor(context)
        : Colors.white.withValues(alpha: 0.88);
    final gradient = isLight
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.14),
                AppTheme.lightSurface,
              ),
              AppTheme.lightSurface,
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              Color.alphaBlend(accent.withValues(alpha: 0.32), AppTheme.bgDeep),
            ],
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          compact ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.md,
          compact ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: gradient,
          border: Border.all(
            color: isLight
                ? accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: isLight
              ? AppTheme.softShadow(context)
              : AppTheme.glowShadow(accent, intensity: 0.14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KilimPatternPainter(
                    drawPattern: true,
                    color: isLight ? accent : Colors.white,
                    opacity: isLight ? 0.035 : 0.05,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -6,
              top: -10,
              child: IgnorePointer(
                child: Icon(
                  icon,
                  size: compact ? 72 : 88,
                  color: (isLight ? accent : Colors.white).withValues(
                    alpha: isLight ? 0.08 : 0.07,
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 44 : 52,
                  height: compact ? 44 : 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isLight ? accent : Colors.white).withValues(
                      alpha: isLight ? 0.12 : 0.16,
                    ),
                    border: Border.all(
                      color: (isLight ? accent : Colors.white).withValues(
                        alpha: isLight ? 0.28 : 0.28,
                      ),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isLight ? accent : Colors.white,
                    size: compact ? 22 : 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading2.copyWith(
                          color: foreground,
                          fontSize: compact ? 17 : 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bölüm başlığı — sol accent çizgisi + uppercase etiket.
class ScreenSectionLabel extends StatelessWidget {
  const ScreenSectionLabel({
    required this.label,
    required this.accent,
    super.key,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: AppTheme.sectionAccent(accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppTheme.textMutedColor(context),
                letterSpacing: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
