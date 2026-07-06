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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final BorderRadius? borderRadius;

  /// true ise arkasını bulanıklaştıran glassmorphism görünümü kullanır.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AppTheme.cardRadius);

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

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? AppTheme.surfaceColor(context))
            : null,
        gradient: gradient,
        borderRadius: br,
        border: gradient == null
            ? Border.all(
                color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                width: 1.0,
              )
            : null,
        boxShadow: AppTheme.softShadow(context),
      ),
      child: child,
    );
  }
}
