import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/reduced_motion_provider.dart';

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
    // Hareket azaltma kontrolü build'de yapılır; burada başlatmak güvenli çünkü
    // reduceMotion=true olduğunda SizedBox.shrink() döner ve controller dispose olur.
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik tercihi: hareketleri azlat modunda sessizce gizle.
    final reduceMotion = context.watch<ReducedMotionProvider>().reduceMotion;
    if (reduceMotion) {
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
