import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pirs-inspired renkli oyun/aksiyon kartı.
///
/// Gradient zemin, sağ altta düşük opaklıklı büyük işlev ikonu (filigran)
/// ve altta başlık/alt başlık taşır. [loading] açıkken dokunuşları yok
/// sayar ve bir progress göstergesi gösterir; başlık okunur kalır.
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
              boxShadow: AppTheme.elevatedShadow(colors.first),
            ),
            child: ConstrainedBox(
              // 44x44 minimum dokunma alanını her içerikte garanti eder.
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Stack(
                children: [
                  Positioned(
                    right: 10,
                    bottom: -8,
                    child: Icon(icon, size: 68, color: Colors.white12),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading2.copyWith(
                            color: Colors.white,
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
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
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
