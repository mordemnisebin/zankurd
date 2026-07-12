import 'package:flutter/material.dart';

/// Web masaüstü geniş ekranlarda içeriği ortalar ve maksimum genişlik
/// sınırı uygular. Mobil/tablet cihazlarda tam ekran davranışı korunur.
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({required this.child, super.key});

  final Widget child;

  /// Masaüstünde içeriğin maksimum genişliği.
  static const double maxContentWidth = 1280;

  /// Bu genişliğin üstünde içerik ortalanır.
  static const double wideThreshold = 900;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Mobil/tablet: tam ekran
    if (screenWidth <= wideThreshold) {
      return child;
    }

    // Masaüstü: içeriği ortala, arka planı doldur
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
              right: Radius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide.none,
                  horizontal: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: -8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
