import 'package:flutter/material.dart';

/// Animation utilities for staggered load animations across sign in/up and home screens
class LoadAnimationSequence {
  // Private constructor to prevent instantiation
  LoadAnimationSequence._();

  // Duration constants for animations
  static const Duration scaleInDuration = Duration(milliseconds: 500);
  static const Duration fadeInDuration = Duration(milliseconds: 500);
  static const Duration slideUpDuration = Duration(milliseconds: 400);

  // Sign In/Sign Up screen animations

  /// Logo scale animation: 0.8 → 1.0, interval 0.2-0.35
  static Animation<double> logoScaleAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.35, curve: Curves.easeOut),
      ),
    );
  }

  /// Title slide animation: 20 → 0, interval 0.4-0.6
  static Animation<double> titleSlideAnimation(AnimationController controller) {
    return Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
      ),
    );
  }

  /// Title fade animation: 0 → 1, interval 0.4-0.6
  static Animation<double> titleFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.4, 0.6, curve: Curves.easeIn),
      ),
    );
  }

  /// Form field 1 fade animation: 0 → 1, interval 0.5-0.75 (1000-1500ms in 2000ms controller)
  static Animation<double> formField1FadeAnimation(
    AnimationController controller,
  ) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.5, 0.75, curve: Curves.easeIn),
      ),
    );
  }

  /// Form field 2 fade animation: 0 → 1, interval 0.55-0.8 (1100-1600ms in 2000ms controller)
  static Animation<double> formField2FadeAnimation(
    AnimationController controller,
  ) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.55, 0.8, curve: Curves.easeIn),
      ),
    );
  }

  /// Button scale animation: 0.95 → 1.0, interval 0.6-0.95 (1200-1900ms in 2000ms controller)
  static Animation<double> buttonScaleAnimation(
    AnimationController controller,
  ) {
    return Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.6, 0.95, curve: Curves.easeOut),
      ),
    );
  }

  /// Button fade animation: 0 → 1, interval 0.6-0.95 (1200-1900ms in 2000ms controller)
  static Animation<double> buttonFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.6, 0.95, curve: Curves.easeIn),
      ),
    );
  }

  // Home screen animations

  /// Hero fade animation: 0 → 1, quick fade-in
  static Animation<double> heroFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
  }

  /// Card fade animation with index-dependent stagger: 0 → 1
  /// Start interval: 0.6 + index*0.1
  static Animation<double> cardFadeAnimation(
    AnimationController controller,
    int index,
  ) {
    final startInterval = 0.6 + (index * 0.1);
    final endInterval = startInterval + 0.2;

    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(startInterval, endInterval, curve: Curves.easeIn),
      ),
    );
  }

  /// Category grid item fade animation with index-dependent stagger: 0 → 1
  /// Start interval: 0.8 + index*0.05
  static Animation<double> categoryGridItemFadeAnimation(
    AnimationController controller,
    int index,
  ) {
    final startInterval = 0.8 + (index * 0.05);
    final endInterval = startInterval + 0.15;

    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(startInterval, endInterval, curve: Curves.easeIn),
      ),
    );
  }
}
