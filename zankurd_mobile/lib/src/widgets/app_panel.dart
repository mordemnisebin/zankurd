import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.color,
    this.borderRadius,
    this.glass = false,
    this.cardType = CardType.secondary,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final BorderRadius? borderRadius;

  /// true ise arkasını bulanıklaştıran glassmorphism görünümü kullanır.
  final bool glass;

  /// Kart öncelik tipi (primary / secondary / info).
  /// Gradient verilirse her zaman primary efekti uygulanır.
  final CardType cardType;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AppRadius.card);

    if (glass) {
      return ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: AppTheme.glassDecoration(
              context,
              borderRadius: br.topLeft.x,
            ),
            child: child,
          ),
        ),
      );
    }

    if (gradient != null) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: AppTheme.premiumCard(
          context,
          gradient: gradient as LinearGradient,
          radius: br.topLeft.x,
        ),
        child: child,
      );
    }

    final decoration = AppTheme.cardDecorationByType(
      context,
      type: cardType,
      radius: br.topLeft.x,
    );

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: decoration.copyWith(
        color: color ?? AppTheme.surfaceColor(context),
        borderRadius: br,
      ),
      child: child,
    );
  }
}
