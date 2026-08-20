import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/kilim_motifs.dart';

/// Visual priority for a mode entry.
///
/// A mode can keep its identity without competing with the screen's single
/// primary action. Primary cards carry the full accent surface; secondary and
/// event cards use a calm tinted surface with the accent reserved for the
/// emblem and boundary.
enum ModeCardEmphasis { primary, secondary, event }

/// Ana sayfadaki büyük oyun/öğrenme modu kartı.
///
/// Ana sayfa üç modu (ders yolu, konu seçimi, hızlı düello) birbirinin
/// aynı `AppRowCard` satırlarıyla gösteriyordu: aynı beyaz zemin, aynı
/// ikon karesi, aynı chevron. Üç farklı iş yapan üç yüzey, ekranda tek bir
/// tekrar eden desen olarak okunuyordu ve hiçbiri "buraya bas" demiyordu.
///
/// Mod kartı bunun tersini yapar: her mod kendi rengini, kendi amblemini
/// ve kendi ağırlığını taşır. Renk burada süs değil, ayırt edici bilgidir
/// — kullanıcı ekrana baktığında üç ayrı şey görmelidir.
///
/// [accent] üzerinde beyaz metin kullanıldığı için çağıranın AA'yı geçen
/// bir ton vermesi gerekir; kart bunu kendi başına düzeltemez.
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
    final titleColor = isPrimary
        ? Colors.white
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = isPrimary
        ? Colors.white.withValues(alpha: 0.88)
        : AppTheme.textSubColor(context);
    final cardDecoration = isPrimary
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(
                alpha: emphasis == ModeCardEmphasis.event ? 0.12 : 0.07,
              ),
              AppTheme.surfaceColor(context),
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentOnSurface.withValues(
                alpha: emphasis == ModeCardEmphasis.event ? 0.38 : 0.26,
              ),
            ),
          );
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      onTap: busy ? null : onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: cardDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Tek motif, tabana yaslı. Kartın etrafını desenle
                    // çevirmek kimliği dekora çevirir.
                    if (isPrimary)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          height: compact ? 26 : 34,
                          child: CustomPaint(
                            painter: KilimPainter(
                              motif: motif,
                              color: Colors.white,
                              opacity: 0.10,
                              count: 9,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        compact ? AppSpacing.sm : AppSpacing.md,
                        AppSpacing.md,
                        compact ? AppSpacing.sm : AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          CategoryEmblem(
                            icon: icon,
                            color: isPrimary ? Colors.white : accentOnSurface,
                            onColor: isPrimary ? Colors.white : accentOnSurface,
                            size: compact ? 40 : 48,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.subtitle.copyWith(
                                    fontSize: compact ? 16 : 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  // Ölçekten okunur: elle fontSize yazmak
                                  // `typography_scale_test` oranını
                                  // yükseltiyor ve ölçek dışına kaçışı
                                  // normalleştiriyor.
                                  style: AppTypography.caption.copyWith(
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (busy)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isPrimary
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : accentOnSurface,
                            ),
                        ],
                      ),
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
