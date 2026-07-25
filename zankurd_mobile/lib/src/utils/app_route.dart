import 'package:flutter/material.dart';

/// Tüm sayfa geçişleri için standart fade+slide animasyonu.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required Widget page, super.settings})
    : super(
        pageBuilder: (context, a, b) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        // Gelen sayfa SOLDURULMAZ, yalnız kaydırılır. Fade kullanıldığında
        // gelen sayfa geçiş boyunca yarı saydam kalıyor ve altındaki eski
        // sayfa okunur biçimde görünüyordu — iki ekranın üst üste bindiği
        // "çift pozlama" görüntüsü buradan geliyordu (2026-07-25 canlı
        // denetimi). Giden sayfa `secondaryAnimation` ile hafifçe geri
        // çekilip karartılır; derinlik hissi fade olmadan da korunur.
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final incoming = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final outgoing = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.03, 0),
              end: Offset.zero,
            ).animate(outgoing),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.85).animate(outgoing),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(incoming),
                child: child,
              ),
            ),
          );
        },
      );

  static AppRoute<T> to<T>(Widget page) => AppRoute<T>(page: page);
}
