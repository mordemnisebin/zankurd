import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kilim_pattern_painter.dart';

/// İkincil ekranların ortak kimlik kartı.
///
/// Kategorî/mockup-4 diliyle tutarlı: koyu düz yüzey + accent renkli ikon
/// çipi + accent renkli ince sınır. Her ekran kendi kimlik rengini
/// [accent] ile taşımaya devam eder; yalnızca büyük gradyan hero + köşe
/// filigran ikon deseni (eski "Pirs-inspired" kalıntısı) terk edildi.
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
          color: AppTheme.surfaceColor(context),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KilimPatternPainter(
                    drawPattern: true,
                    color: accent,
                    opacity: 0.05,
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
                    color: accent.withValues(alpha: 0.16),
                  ),
                  child: Icon(icon, color: accent, size: compact ? 22 : 26),
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
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: compact ? 17 : 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textSubColor(context),
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
