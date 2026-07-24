import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Oyun/mod kartı — Pirs/TRT tarzı doygun gradyan zemin + beyaz tipografi.
///
/// [tile]: 2×2 ızgara hücresi (ikon üstte).
/// [row]: tam genişlik satır (ikon solda) — Pêşbazî listesi.
class ColorfulActionCard extends StatelessWidget {
  const ColorfulActionCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.loading = false,
    this.semanticLabel,
    this.style = ColorfulActionCardStyle.row,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool loading;
  final String? semanticLabel;
  final ColorfulActionCardStyle style;

  @override
  Widget build(BuildContext context) {
    final start = colors.first;
    final end = colors.length > 1
        ? colors[1]
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.14), start);

    final effectiveLabel =
        semanticLabel ??
        (subtitle != null && !loading ? '$title. $subtitle' : title);

    return Semantics(
      button: true,
      enabled: !loading,
      label: effectiveLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start, end],
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: start.withValues(alpha: 0.28),
                offset: const Offset(0, 8),
                blurRadius: 18,
                spreadRadius: -6,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 4),
                blurRadius: 10,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: InkWell(
              onTap: loading ? null : onTap,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: style == ColorfulActionCardStyle.tile
                  ? _TileBody(
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                      loading: loading,
                    )
                  : _RowBody(
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                      loading: loading,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ColorfulActionCardStyle { row, tile }

class _RowBody extends StatelessWidget {
  const _RowBody({
    required this.title,
    required this.icon,
    required this.loading,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            _IconChip(icon: icon, size: 48, iconSize: 24),
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
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
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
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!loading)
              Icon(
                AppIcons.chevronRight,
                color: Colors.white.withValues(alpha: 0.85),
              ),
          ],
        ),
      ),
    );
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.title,
    required this.icon,
    required this.loading,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconChip(icon: icon, size: 40, iconSize: 20),
            const SizedBox(height: 10),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            else ...[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}
