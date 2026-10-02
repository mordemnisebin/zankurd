import 'dart:math';

import 'package:flutter/material.dart';
import '../providers/reduced_motion_provider.dart';
import 'sahne/sahne.dart';

/// Reaksiyon balonunun ekran üzerindeki hareket bölgesi.
enum FloatingReactionPlacement {
  /// Quiz/yariş sahnesindeki mevcut serbest uçuş yörüngesi.
  free,

  /// Oda lobisinde oyuncu kartları ve ana kontrolleri örtmeyen üst bant.
  roomHeader,
}

const _roomHeaderBubbleWidth = 184.0;
const _reactionPeakScale = 1.15;
const _roomHeaderRightMargin = 12.0;
const _roomHeaderMinMobileX = 84.0;
const _roomHeaderTrailingBandWidth = 120.0;

/// Oda reaksiyonunu sağ taraftaki güvenli başlık bandına yerleştirir.
///
/// Geniş ekranda lobi içeriği 680 px'e ortalanır. Sabit `minX = 84`
/// kullanmak, en sola düşen reaksiyonu ortalanmış geri düğmesinin üzerine
/// taşıyabiliyordu. Sağ kenardan türetilen dar bant hem telefonda geri
/// düğmesini korur hem tablet/web genişliğinde reaksiyonu boş başlık alanında
/// tutar.
@visibleForTesting
double roomHeaderReactionX({
  required double screenWidth,
  required double startXRatio,
}) {
  const peakBubbleWidth = _roomHeaderBubbleWidth * _reactionPeakScale;
  final maxX = max(0.0, screenWidth - peakBubbleWidth - _roomHeaderRightMargin);
  final minX = min(
    maxX,
    max(_roomHeaderMinMobileX, maxX - _roomHeaderTrailingBandWidth),
  );
  final normalized = ((startXRatio - 0.25) / 0.5).clamp(0.0, 1.0);
  return minX + (maxX - minX) * normalized;
}

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
    this.placement = FloatingReactionPlacement.free,
    super.key,
  });

  final Widget child;
  final FloatingReactionController? controller;
  final FloatingReactionPlacement placement;

  /// Görünen her tepki balonunun anahtarı (testler ve yerleşim bekçileri
  /// balonu görünüşünden değil bununla bulur).
  static const bubbleKey = ValueKey('floating-reaction-bubble');

  @override
  State<FloatingReactionOverlay> createState() =>
      _FloatingReactionOverlayState();
}

class FloatingReactionController extends ChangeNotifier {
  final List<FloatingReactionBubble> _activeBubbles = [];
  int _nextBubbleId = 0;

  List<FloatingReactionBubble> get activeBubbles =>
      List.unmodifiable(_activeBubbles);

  void triggerReaction(String text, {String? senderName}) {
    final bubble = FloatingReactionBubble(
      id: 'reaction_${_nextBubbleId++}',
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
  late FloatingReactionController _controller;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    _adoptController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant FloatingReactionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    if (_internalController) {
      _controller.dispose();
    }
    _adoptController(widget.controller);
  }

  void _adoptController(FloatingReactionController? externalController) {
    if (externalController != null) {
      _controller = externalController;
      _internalController = false;
      return;
    }
    _controller = FloatingReactionController();
    _internalController = true;
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

                final visibleBubbles =
                    widget.placement == FloatingReactionPlacement.roomHeader
                    ? bubbles.take(1)
                    : bubbles;

                return Stack(
                  children: [
                    for (final bubble in visibleBubbles)
                      _SingleAnimatedReactionBubble(
                        key: ValueKey(bubble.id),
                        bubble: bubble,
                        placement: widget.placement,
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
    required this.placement,
    required this.onComplete,
    super.key,
  });

  final FloatingReactionBubble bubble;
  final FloatingReactionPlacement placement;
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
    _horizontalDrift = widget.placement == FloatingReactionPlacement.roomHeader
        ? 0
        : (Random().nextDouble() - 0.5) * 60;
    _animController = AnimationController(
      vsync: this,
      duration: widget.placement == FloatingReactionPlacement.roomHeader
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 1800),
    );

    final yTravel = widget.placement == FloatingReactionPlacement.roomHeader
        ? -4.0
        : -280.0;
    _yAnimation = Tween<double>(begin: 0.0, end: yTravel).animate(
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
    final reduceMotion =
        ReducedMotionProvider.isReducedIn(context) ||
        sahneMotionReduced(context);
    if (reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete());
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final startX = screenWidth * widget.bubble.startXRatio;
    final inRoomHeader =
        widget.placement == FloatingReactionPlacement.roomHeader;
    final t = SahneTokens.of(context);
    final hasSender = widget.bubble.senderName?.trim().isNotEmpty ?? false;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final currentY = inRoomHeader
            ? mediaQuery.padding.top + 12 + _yAnimation.value
            : screenHeight * 0.75 + _yAnimation.value;
        final currentX = inRoomHeader
            ? roomHeaderReactionX(
                screenWidth: screenWidth,
                startXRatio: widget.bubble.startXRatio,
              )
            : startX + (_horizontalDrift * _animController.value);

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: inRoomHeader
                      ? _roomHeaderBubbleWidth
                      : double.infinity,
                ),
                // 2026-09-29 Şahnê: Kulis (`s2`) plaka, M pah, Halka 1 Zêr
                // kaş; bulanık gölge yok. Gönderen kalın açıklama Zêr metni,
                // tepki Gövde 700 birincil metin.
                child: DecoratedBox(
                  key: FloatingReactionOverlay.bubbleKey,
                  decoration: ShapeDecoration(
                    color: t.s2,
                    shape: SahneShape.withSide(
                      SahneShape.m,
                      t.gold,
                      width: SahneRing.r1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SahneSpace.x3,
                      vertical: SahneSpace.x2,
                    ),
                    child: inRoomHeader
                        ? Text.rich(
                            TextSpan(
                              children: [
                                if (hasSender) ...[
                                  TextSpan(
                                    text: widget.bubble.senderName!,
                                    style: SahneType.captionStrong.copyWith(
                                      color: t.goldTx,
                                    ),
                                  ),
                                  const TextSpan(text: ' · '),
                                ],
                                TextSpan(text: widget.bubble.text),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SahneType.bodyStrong.copyWith(color: t.tx),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasSender)
                                Text(
                                  widget.bubble.senderName!,
                                  style: SahneType.captionStrong.copyWith(
                                    color: t.goldTx,
                                  ),
                                ),
                              Text(
                                widget.bubble.text,
                                style: SahneType.bodyStrong.copyWith(
                                  color: t.tx,
                                ),
                              ),
                            ],
                          ),
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
