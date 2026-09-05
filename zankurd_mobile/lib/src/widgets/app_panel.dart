import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.gradient,
    this.color,
    this.borderRadius,
    this.cardType = CardType.secondary,
    this.onTap,
    this.semanticLabel,
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

  /// Kart öncelik tipi (primary / secondary / info).
  /// Gradient verilirse her zaman primary efekti uygulanır.
  final CardType cardType;

  /// Dokunulabilir panelin ekran okuyucuda tek bir eylem olarak duyurulması.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AppTheme.panelRadius);
    return _wrapTap(_buildPanel(context, br), br);
  }

  Widget _wrapTap(Widget panel, BorderRadius br) {
    if (onTap == null && semanticLabel == null) return panel;

    final content = onTap == null
        ? panel
        : Stack(
            children: [
              panel,
              Positioned.fill(
                child: ExcludeSemantics(
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: br,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      container: onTap != null || semanticLabel != null,
      button: onTap != null,
      enabled: onTap == null ? null : true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildPanel(BuildContext context, BorderRadius br) {
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
