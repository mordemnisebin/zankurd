import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: tint.withValues(alpha: 0.35)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: tint, size: 24),
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
                          style: AppTypography.heading2.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        if (loading)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: tint,
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
                                color: AppTheme.textSubColor(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!loading)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMutedColor(context),
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
