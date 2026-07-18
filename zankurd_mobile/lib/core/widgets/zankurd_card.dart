import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Reusable card component using ZanKurd's design tokens.
///
/// - [CardType.primary] → gradient + glow, ana CTA / soru kartı.
/// - [CardType.secondary] → surface + border, standart içerik kartı.
/// - [CardType.info] → sade border + minimal shadow, istatistik/yardımcı kart.
///
/// Explicit [gradient] / [glowColor] verilirse bunlar öncelikli olur.
/// Supports optional tap handling.
class ZankurdCard extends StatelessWidget {
  const ZankurdCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.glowColor,
    this.radius,
    this.cardType = CardType.secondary,
    this.onTap,
  });

  /// Content inside the card.
  final Widget child;

  /// Inner padding (default: [AppTheme.pagePadding]).
  final EdgeInsetsGeometry? padding;

  /// Optional gradient background (overrides [cardType] decoration).
  final LinearGradient? gradient;

  /// Optional glow shadow colour (paired with [gradient]).
  final Color? glowColor;

  /// Corner radius (default: [AppTheme.cardRadius] = 16).
  final double? radius;

  /// Visual weight tipi (primary / secondary / info).
  final CardType cardType;

  /// Optional tap callback — wraps the card in a [GestureDetector].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppTheme.cardRadius;

    late final Decoration decoration;
    if (gradient != null || glowColor != null) {
      decoration = AppTheme.premiumCard(
        context,
        gradient: gradient,
        glowColor: glowColor,
        radius: r,
      );
    } else {
      decoration = AppTheme.cardDecorationByType(
        context,
        type: cardType,
        radius: r,
      );
    }

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
