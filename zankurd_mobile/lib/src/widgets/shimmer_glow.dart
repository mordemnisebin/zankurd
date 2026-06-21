import 'package:flutter/material.dart';
import '../utils/test_environment.dart';

/// Kartların üzerine premium bir parlama (shimmer/glow) efekti ekleyen widget.
/// Soldan sağa doğru periyodik olarak kayan ışık süzmesi oluşturur.
class ShimmerGlow extends StatefulWidget {
  const ShimmerGlow({super.key});

  @override
  State<ShimmerGlow> createState() => _ShimmerGlowState();
}

class _ShimmerGlowState extends State<ShimmerGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    if (!isFlutterTestEnvironment) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isFlutterTestEnvironment) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: FractionallySizedBox(
              widthFactor: 2.0,
              alignment: Alignment(
                -1.0 + (_controller.value * 3.0), // -1'den 2'ye kayar
                0.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.18), // Parlama merkezi
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
