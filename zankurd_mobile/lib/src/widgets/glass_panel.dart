import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Cam-morfizm (glassmorphism) efektli panel widget'ı.
/// Mevcut AppPanel'e alternatif olarak, arkasındaki içeriği
/// bulanıklaştırarak modern bir görünüm sağlar.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.blur = 12.0,
    this.opacity = 0.12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = !AppTheme.isLight(context);
    final br = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: opacity)
                : Colors.white.withValues(alpha: opacity + 0.4),
            borderRadius: br,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
