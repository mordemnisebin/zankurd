import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kilim_pattern_painter.dart';

/// Ana sayfadan Pêşbazî (Oyna) sekmesine kısa geçiş kartı — [home_screen.dart]
/// yorumundaki "kısa teaser" sözü, [DailyRaceCard] ile aynı tek-satır kart
/// kalıbını kullanır (Pirs sadeliği: ayrı 2x2 mod grid'i tekrarlamaz).
class PlayTeaserCard extends StatelessWidget {
  const PlayTeaserCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Semantics(
      button: true,
      label: ku ? 'Zû bilîze' : 'Hemen oyna',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('home-play-teaser'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(
                      AppTheme.playPink.withValues(alpha: 0.16),
                      AppTheme.surfaceHiColor(context),
                    ),
                    Color.alphaBlend(
                      AppTheme.brandGreen.withValues(alpha: 0.08),
                      AppTheme.surfaceHiColor(context),
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppTheme.playPink.withValues(alpha: 0.3),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: KilimPatternPainter(
                          drawPattern: true,
                          color: AppTheme.playPink,
                          opacity: 0.04,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.playPink.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_esports_rounded,
                          color: AppTheme.playPink,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              ku ? 'Zû bilîze' : 'Hemen oyna',
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ku
                                  ? 'Duel, oda an çerx — hemû li Pêşbazîyê.'
                                  : 'Düello, oda veya çark — hepsi Yarış\'ta.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.playPink,
                      ),
                    ],
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
