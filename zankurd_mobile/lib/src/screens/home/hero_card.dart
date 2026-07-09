import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kilim_pattern_painter.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.isKu,
    required this.loading,
    required this.onCreateRoom,
    required this.onJoinRoom,
    required this.onQuickMatch,
    this.drawPattern = true,
    super.key,
  });

  final bool isKu;
  final bool loading;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback onQuickMatch;
  final bool drawPattern;

  @override
  Widget build(BuildContext context) {
    // Premium Derin Yeşil ve Orman tonlarında gradyan (ZanKurd kurumsal tonu)
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.secondaryAccent,
        AppTheme.bgDeep,
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.bgDeep.withValues(alpha: 0.4),
            offset: const Offset(0, 10),
            blurRadius: 28,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Kilim Geometrisi (CustomPainter - Maksimum %6 Opaklık)
          Positioned.fill(
            child: CustomPaint(
              painter: KilimPatternPainter(
                drawPattern: drawPattern,
                color: Colors.white,
                opacity: 0.05, // %5 Opaklık
              ),
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.6), // Online durum noktası
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.gold.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              isKu ? 'Odeya Zindî Vekirî' : 'Canlı Oda Açık',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isKu
                    ? 'Bi hevalan re\npêşbikeve'
                    : 'Arkadaşlarınla\ncanlı yarış',
                style: AppTypography.display.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Pirs-style hierarchy: one clear primary play CTA, then room actions
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGradientStart.withValues(
                          alpha: 0.28,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onQuickMatch,
                    icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                    label: Text(
                      isKu ? '1vs1 — Dest pê bike' : '1vs1 — Hemen oyna',
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onCreateRoom,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        child: Text(
                          isKu ? 'Oda ava bike' : 'Oda kur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onJoinRoom,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        child: Text(
                          isKu ? 'Kodê tevlî bibe' : 'Kodla katıl',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
