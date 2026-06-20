import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    _particles = List.generate(80, (index) => _ConfettiParticle.random());
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
  });

  final double x; // 0.0 to 1.0
  final double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final int shape; // 0: circle, 1: square, 2: triangle

  factory _ConfettiParticle.random() {
    final random = Random();
    final x = random.nextDouble();
    final y = -0.1 - random.nextDouble() * 0.2;

    final angle = pi / 4 + random.nextDouble() * pi / 2; // downwards angle
    final speed = 3.0 + random.nextDouble() * 5.0;
    final vx = cos(angle) * speed * 0.3; // drift
    final vy = sin(angle) * speed;

    final size = 6.0 + random.nextDouble() * 8.0;
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.tealAccent,
    ];
    final color = colors[random.nextInt(colors.length)];

    final rotation = random.nextDouble() * 2 * pi;
    final rotationSpeed = (random.nextDouble() - 0.5) * 5 * pi;

    final shape = random.nextInt(3);

    return _ConfettiParticle(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      size: size,
      color: color,
      rotation: rotation,
      rotationSpeed: rotationSpeed,
      shape: shape,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final gravity = 200.0 * progress * progress;
      final currentX = (p.x * size.width) + (p.vx * size.width * progress);
      final currentY =
          (p.y * size.height) + (p.vy * size.height * progress) + gravity;
      final currentRotation = p.rotation + (p.rotationSpeed * progress);

      if (currentX < -50 ||
          currentX > size.width + 50 ||
          currentY > size.height + 50) {
        continue;
      }

      paint.color = p.color;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);

      if (p.shape == 0) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (p.shape == 1) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        );
      } else {
        final path = Path()
          ..moveTo(0, -p.size / 2)
          ..lineTo(-p.size / 2, p.size / 2)
          ..lineTo(p.size / 2, p.size / 2)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
