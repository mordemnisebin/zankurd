import 'package:flutter/material.dart';

/// Web masaüstü/tablet geniş ekranlarda içeriği ortalar ve maksimum genişlik
/// sınırı uygular. Mobil cihazlarda tam ekran davranışı korunur.
///
/// Mevcut uygulama: tek sütun + ortalama + [maxContentWidth] sınırı.
/// Gerçek iki sütunlu tablet düzeni kapsamlı bir tasarım işi;
/// izole bir sprint olarak planlanmalı (M-12).
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({required this.child, super.key});

  final Widget child;

  /// Masaüstünde içeriğin maksimum genişliği.
  ///
  /// [AppShell] 768 px'de masaüstü gezinmesine geçer. Navigator'ı bunun
  /// altında sınırlamak breakpoint'i erişilemez yaptığı için kabuk ve kendi
  /// içerik sınırları çalışabilecek güvenli bir masaüstü genişliği korunur.
  static const double maxContentWidth = 1200;

  /// Bu genişliğin üstünde içerik ortalanır.
  static const double wideThreshold = 600;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Mobil: tam ekran
    if (screenWidth <= wideThreshold) {
      return child;
    }

    // Tablet/masaüstü: içeriği ortala ve geniş ekran taşmasını sınırla.
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveWrapper.maxContentWidth,
          ),
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
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.3),
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
