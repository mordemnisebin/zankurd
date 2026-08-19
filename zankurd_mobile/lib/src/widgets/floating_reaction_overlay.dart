import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';

/// Canlı çok oyunculu odalarda ve yarışlarda ekranda süzülen hızlı reaksiyon baloncukları.
class FloatingReactionBubble {
  FloatingReactionBubble({
    required this.id,
    required this.text,
    this.senderName,
  }) : startXRatio = 0.25 + Random().nextDouble() * 0.5;

  final String id;
  final String text;
  final String? senderName;
  final double startXRatio;
}

class FloatingReactionOverlay extends StatefulWidget {
  const FloatingReactionOverlay({
    required this.child,
    this.controller,
    super.key,
  });

  final Widget child;
  final FloatingReactionController? controller;

  @override
  State<FloatingReactionOverlay> createState() =>
      _FloatingReactionOverlayState();
}

class FloatingReactionController extends ChangeNotifier {
  final List<FloatingReactionBubble> _activeBubbles = [];
  List<FloatingReactionBubble> get activeBubbles =>
      List.unmodifiable(_activeBubbles);

  void triggerReaction(String text, {String? senderName}) {
    final bubble = FloatingReactionBubble(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      text: text,
      senderName: senderName,
    );
    _activeBubbles.add(bubble);
    notifyListeners();
  }

  void removeReaction(String id) {
    _activeBubbles.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}

class _FloatingReactionOverlayState extends State<FloatingReactionOverlay> {
  late final FloatingReactionController _controller;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = FloatingReactionController();
      _internalController = true;
    }
  }

  @override
  void dispose() {
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final bubbles = _controller.activeBubbles;
                if (bubbles.isEmpty) return const SizedBox.shrink();

                return Stack(
                  children: [
                    for (final bubble in bubbles)
                      _SingleAnimatedReactionBubble(
                        key: ValueKey(bubble.id),
                        bubble: bubble,
                        onComplete: () => _controller.removeReaction(bubble.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SingleAnimatedReactionBubble extends StatefulWidget {
  const _SingleAnimatedReactionBubble({
    required this.bubble,
    required this.onComplete,
    super.key,
  });

  final FloatingReactionBubble bubble;
  final VoidCallback onComplete;

  @override
  State<_SingleAnimatedReactionBubble> createState() =>
      _SingleAnimatedReactionBubbleState();
}

class _SingleAnimatedReactionBubbleState
    extends State<_SingleAnimatedReactionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _yAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final double _horizontalDrift;

  @override
  void initState() {
    super.initState();
    _horizontalDrift = (Random().nextDouble() - 0.5) * 60;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _yAnimation = Tween<double>(begin: 0.0, end: -280.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 65),
    ]).animate(_animController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_animController);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ReducedMotionProvider.isReducedIn(context);
    if (reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete());
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final startX = screenWidth * widget.bubble.startXRatio;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final currentY = screenHeight * 0.75 + _yAnimation.value;
        final currentX = startX + (_horizontalDrift * _animController.value);

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.culturalBrandBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.bubble.senderName != null &&
                        widget.bubble.senderName!.trim().isNotEmpty) ...[
                      Text(
                        widget.bubble.senderName!,
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      widget.bubble.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
