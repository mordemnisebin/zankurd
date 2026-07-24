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
    this.cardType = CardType.secondary,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final BorderRadius? borderRadius;

  /// Verilirse panel dokunulabilir olur; opak yuzeyin ustune seffaf bir
  /// InkWell katmani eklenerek ripple geri bildirimi saglanir (mevcut
  /// gorunumu/golgeyi bozmaz).
  final VoidCallback? onTap;

  /// Kart öncelik tipi (primary / secondary / info / glass).
  /// Gradient verilirse her zaman primary efekti uygulanır.
  final CardType cardType;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AppRadius.card);
    return _wrapTap(_buildPanel(context, br), br);
  }

  Widget _wrapTap(Widget panel, BorderRadius br) {
    if (onTap == null) return panel;
    return Stack(
      children: [
        panel,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: br,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context, BorderRadius br) {
    if (cardType == CardType.glass) {
      return ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: AppTheme.cardDecorationByType(
              context,
              type: CardType.glass,
              radius: br.topLeft.x,
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
