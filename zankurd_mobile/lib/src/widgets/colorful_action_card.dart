import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Oyun/aksiyon mod kartı — Kategorî'nin kompakt satır diliyle tutarlı:
/// koyu düz yüzey + sol renkli ikon çipi + başlık/alt başlık + sağ ok.
/// Eski "Pirs-inspired" büyük gradyan zemin + köşe filigran ikon deseni
/// (Faz 0-6'da mockup'ta referansı olmadığı için hiç güncellenmemişti)
/// burada terk edildi; her modun kimlik rengi artık ikon çipinde yaşıyor.
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
    final tint = colors.first;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors.length >= 2
          ? [colors.first, colors.last]
          : [tint, Color.alphaBlend(Colors.black.withValues(alpha: 0.18), tint)],
    );

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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.28),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (loading)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.2,
                              ),
                            ),
                          )
                        else if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!loading)
                    Icon(
                      AppIcons.chevronRight,
                      color: Colors.white.withValues(alpha: 0.8),
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
