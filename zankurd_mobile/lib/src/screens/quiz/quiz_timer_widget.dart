import 'dart:math';

import 'package:flutter/material.dart';
import '../../providers/reduced_motion_provider.dart';

import '../../theme/app_theme.dart';

/// Dairesel geri sayım göstergesi. Son 5 saniyede nabız animasyonu ve
/// renk geçişi (yeşil → amber → kırmızı) ile uyarı verir.
class QuizTimerWidget extends StatefulWidget {
  const QuizTimerWidget({
    required this.animation,
    required this.maxSeconds,
    required this.isPaused,
    super.key,
  });

  final Animation<double> animation;
  final int maxSeconds;
  final bool isPaused;

  @override
  State<QuizTimerWidget> createState() => _QuizTimerWidgetState();
}

class _QuizTimerWidgetState extends State<QuizTimerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.animation.addListener(_handleAnimationTick);
  }

  @override
  void didUpdateWidget(covariant QuizTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused) {
      _pulseController.stop();
    }
  }

  void _handleAnimationTick() {
    final value = widget.animation.value;
    final seconds = (value * widget.maxSeconds).ceil();
    final shouldPulse = seconds <= 5 && seconds > 0 && !widget.isPaused;

    // Son 5 saniyedeki nabız "hareketi azalt" açıkken atmaz. İşlevsel
    // bilgi (kalan süre) rakamda ve halkada zaten var; nabız yalnız
    // vurgudur (2026-07-31 denetimi).
    final reduceMotion = ReducedMotionProvider.isReducedIn(context);
    if (shouldPulse && !reduceMotion) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimationTick);
    _pulseController.dispose();
    super.dispose();
  }

  Color _getTimerColor(double progress) {
    if (progress > 0.5) {
      return Color.lerp(
        const Color(0xFFFFC107), // Amber
        AppTheme.brand,
        (progress - 0.5) * 2,
      )!;
    } else {
      return Color.lerp(
        AppTheme.wrong, // Red
        const Color(0xFFFFC107), // Amber
        progress * 2,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final progress = widget.animation.value;
        final seconds = (progress * widget.maxSeconds).ceil();
        final color = _getTimerColor(progress);

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            final isAlert = seconds <= 5 && seconds > 0 && !widget.isPaused;
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isAlert
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(36, 36),
                      painter: _TimerPainter(progress: progress, color: color),
                    ),
                    Text(
                      '$seconds',
                      style: AppTypography.bodyMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        shadows: isAlert
                            ? [
                                Shadow(
                                  color: color.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimerPainter extends CustomPainter {
  _TimerPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 2, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
