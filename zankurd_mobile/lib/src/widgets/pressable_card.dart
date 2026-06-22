import 'package:flutter/material.dart';

/// Dokununca hafifçe küçülen (scale 0.97) tıklanabilir kart sarmalayıcı.
class PressableCard extends StatefulWidget {
  const PressableCard({
    required this.child,
    required this.onTap,
    this.borderRadius = 20,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
