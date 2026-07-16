import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pirs-inspired renkli oyun/aksiyon kartı.
///
/// Gradient zemin, sol üstte yuvarlak ikon konteyneri, sağ altta büyük
/// filigran ikonu ve altta başlık/alt başlık taşır. [loading] açıkken
/// dokunuşları yok sayar ve bir progress göstergesi gösterir.
class ColorfulActionCard extends StatelessWidget {
  const ColorfulActionCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.loading = false,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool loading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: semanticLabel ?? title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 72,
                minWidth: 44,
              ),
              child: Stack(
                children: [
                  // Decorative glow circle top-right
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Large watermark icon bottom-right
                  Positioned(
                    right: 8,
                    bottom: -6,
                    child: Icon(icon, size: 78, color: Colors.white12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon in glass container at top-left
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(
                              AppRadius.sm,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.26),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading2.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0x44000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            ),
                          )
                        else if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.84),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }
}
