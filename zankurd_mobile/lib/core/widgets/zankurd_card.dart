import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Reusable card component using ZanKurd's design tokens.
///
/// Wraps [AppTheme.cardDecoration] for surface cards and
/// [AppTheme.premiumCard] for gradient/glow variants.
/// Supports optional tap handling.
class ZankurdCard extends StatelessWidget {
  const ZankurdCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.glowColor,
    this.radius,
    this.onTap,
  });

  /// Content inside the card.
  final Widget child;

  /// Inner padding (default: [AppTheme.pagePadding]).
  final EdgeInsetsGeometry? padding;

  /// Optional gradient background (uses [AppTheme.premiumCard] when provided).
  final LinearGradient? gradient;

  /// Optional glow shadow colour (paired with [gradient]).
  final Color? glowColor;

  /// Corner radius (default: [AppTheme.cardRadius] = 16).
  final double? radius;

  /// Optional tap callback — wraps the card in a [GestureDetector].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppTheme.cardRadius;

    final decoration = (gradient != null || glowColor != null)
        ? AppTheme.premiumCard(
            context,
            gradient: gradient,
            glowColor: glowColor,
            radius: r,
          )
        : AppTheme.cardDecoration(context, radius: r);

    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.pagePadding),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
