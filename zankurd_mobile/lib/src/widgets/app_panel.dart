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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppTheme.surface) : null,
        gradient: gradient,
        borderRadius: br,
        border: gradient == null ? Border.all(color: AppTheme.border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
