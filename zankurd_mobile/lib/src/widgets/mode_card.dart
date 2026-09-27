import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/kilim_motifs.dart';

/// Visual priority for a mode entry.
///
/// A mode keeps its identity in the emblem, while the card surface follows the
/// shared ZanKurd hierarchy. This prevents every mode from looking like a
/// separate campaign tile.
enum ModeCardEmphasis { primary, secondary, event }

/// Ana sayfa ve Oyna merkezindeki ortak mod kartı.
///
/// Birincil mod yalnız marka yeşiliyle öne çıkar. Diğer modlarda kategori
/// rengi kartı boyamaz; küçük amblemde kalır. Böylece ekran tek bir ürün gibi
/// görünür, fakat kullanıcı modları hâlâ hızlıca ayırt edebilir.
class ModeCard extends StatelessWidget {
  const ModeCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.motif = KilimMotif.step,
    this.compact = false,
    this.busy = false,
    this.emphasis = ModeCardEmphasis.primary,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final KilimMotif motif;

  /// Sunucu isteği sürerken chevron yerine ilerleme gösterilir ve dokunuş
  /// kapanır; çift dokunuş ikinci bir istek başlatmamalı.
  final bool busy;

  /// Dar düzende yüksekliği kısar; iki satır metin yerine bir satır.
  final bool compact;
  final ModeCardEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final isPrimary = emphasis == ModeCardEmphasis.primary;
    final accentOnSurface = AppColors.readableAccent(context, accent);
    final progressColor = isPrimary ? Colors.white : accentOnSurface;
    final titleColor = isPrimary
        ? Colors.white
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = isPrimary
        ? Colors.white.withValues(alpha: 0.88)
        : AppTheme.textSubColor(context);
    final cardDecoration = BoxDecoration(
      color: isPrimary
          ? AppTheme.culturalBrandBg
          : AppTheme.surfaceColor(context),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: isPrimary
            ? Colors.white.withValues(alpha: 0.10)
            : AppTheme.borderColor(context),
      ),
      boxShadow: isPrimary ? AppTheme.cardShadow(context) : const <BoxShadow>[],
    );
    final enabled = !busy && onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: cardDecoration,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  compact ? AppSpacing.sm : AppSpacing.md,
                  AppSpacing.md,
                  compact ? AppSpacing.sm : AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 40 : 44,
                      height: compact ? 40 : 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.10)
                            : AppColors.iconTileBg(context, accent),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        icon,
                        color: isPrimary ? Colors.white : accentOnSurface,
                        size: compact ? 20 : 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTypography.subtitle.copyWith(
                              fontSize: compact ? 16 : 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTypography.caption.copyWith(
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (busy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.82)
                            : AppTheme.textMutedColor(context),
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
