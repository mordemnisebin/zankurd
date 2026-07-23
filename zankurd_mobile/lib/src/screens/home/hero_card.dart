import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
    return Container(
      key: const ValueKey('home-multiplayer-hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.brandDeep,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandDeep.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
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
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                              ),
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
                isKu ? 'Rast bikeve\npêşbirkê' : 'Hemen\nyarış',
                style: AppTypography.heading1.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isKu
                    ? 'Pêşbirkekê hilbijêre an bi hevalên xwe re odeyek ava bike.'
                    : 'Hemen bir yarış başlat veya arkadaşlarınla oda kur.',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Pirs-style hierarchy: one clear primary play CTA, then room actions
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onQuickMatch,
                    icon: const Icon(AppIcons.bolt, color: AppTheme.brand),
                    label: ExcludeSemantics(
                      // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
                      child: Text(
                        isKu ? '1vs1 — Dest pê bike' : '1vs1 — Hemen yarış',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
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
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isKu ? 'Oda ava bike' : 'Oda kur',
                              maxLines: 1,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isKu ? 'Kodê tevlî bibe' : 'Kodla katıl',
                              maxLines: 1,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
