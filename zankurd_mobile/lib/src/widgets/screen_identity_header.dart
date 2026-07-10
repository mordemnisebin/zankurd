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
    // Açık temada da kart renkli kimlik taşır; metin her iki modda beyaz.
    final end = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.55 : 0.35),
      isLight ? const Color(0xFF1A2E24) : AppTheme.bgDeep,
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, end],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: AppTheme.glowShadow(accent, intensity: 0.14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KilimPatternPainter(
                    drawPattern: true,
                    color: Colors.white,
                    opacity: 0.05,
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
                  color: Colors.white.withValues(alpha: 0.07),
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
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
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
                          color: Colors.white,
                          fontSize: compact ? 17 : 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
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
