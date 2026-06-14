import 'package:flutter/material.dart';

/// Tüm sayfa geçişleri için standart fade+slide animasyonu.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required Widget page, super.settings})
    : super(
        pageBuilder: (context, a, b) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      );

  static AppRoute<T> to<T>(Widget page) => AppRoute<T>(page: page);
  static AppRoute<T> replace<T>(Widget page) => AppRoute<T>(page: page);
}
