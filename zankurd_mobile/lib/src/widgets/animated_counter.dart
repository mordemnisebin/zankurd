import 'package:flutter/material.dart';

/// Tamsayı değer değiştiğinde eski değerden yeni değere yumuşak geçişle
/// sayan metin. Coin / XP gibi anlık artan değerler için kullanılır.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    super.key,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      // begin her zaman değişmeli ki TweenAnimationBuilder yeniden tetiklensin;
      // value değişince Flutter eski tween sonundan yenisine animasyon yapar.
      tween: IntTween(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, _) {
        return Text('$animatedValue', style: style);
      },
    );
  }
}
