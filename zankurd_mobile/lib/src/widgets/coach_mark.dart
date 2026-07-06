import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bir rehber turu adımı: hedef widget'ın konumu + açıklayıcı metin.
class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.icon,
    required this.titleKu,
    required this.titleTr,
    required this.descriptionKu,
    required this.descriptionTr,
  });

  final GlobalKey targetKey;
  final IconData icon;
  final String titleKu;
  final String titleTr;
  final String descriptionKu;
  final String descriptionTr;
}

/// Ekranın üstüne bindirilen, hedef widget'ı aydınlık bırakıp gerisini
/// karartan ve yanına açıklayıcı balon gösteren basit bir rehber turu.
///
/// Paket bağımlılığı yok: CustomPainter ile "spotlight" deliği çizilir,
/// tooltip balonu hedefin üstünde/altında (yer varsa) konumlanır.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    required this.steps,
    required this.onFinished,
    this.isKu = false,
    super.key,
  });

  final List<CoachMarkStep> steps;
  final VoidCallback onFinished;
  final bool isKu;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _index = 0;
  Rect? _rect;
  int _measuredForIndex = -1;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  /// Hedefin konumunu build sırasında DEĞİL, bir sonraki frame'de ölçer.
  /// Build anında RenderBox.localToGlobal çağırmak, ağaç henüz tam layout
  /// olmadan (ör. sayfa geçiş animasyonu sürerken) "hasSize" assertion'ına
  /// çarpabiliyor — bu yüzden ölçüm her zaman post-frame'e ertelenir.
  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = widget.steps[_index].targetKey;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) {
        // Hedef hiç mount olmamış (ör. bu tab hiç açılmadı) — bu adımı atla.
        _next();
        return;
      }
      final topLeft = box.localToGlobal(Offset.zero);
      setState(() {
        _rect = topLeft & box.size;
        _measuredForIndex = _index;
      });
    });
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() {
      _index++;
      _rect = null;
    });
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final screenSize = MediaQuery.sizeOf(context);
    final rect = _measuredForIndex == _index ? _rect : null;

    if (rect == null) {
      return const SizedBox.shrink();
    }

    final highlightRect = rect.inflate(8);
    final showBelow = highlightRect.top < screenSize.height * 0.4;
    final tooltipTop = showBelow
        ? highlightRect.bottom + 16
        : null;
    final tooltipBottom = !showBelow
        ? screenSize.height - highlightRect.top + 16
        : null;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _next,
                child: CustomPaint(
                  painter: _SpotlightPainter(highlightRect),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: tooltipTop,
              bottom: tooltipBottom,
              child: _CoachMarkBubble(
                step: step,
                index: _index,
                total: widget.steps.length,
                isKu: widget.isKu,
                onNext: _next,
                onSkip: widget.onFinished,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final combined = Path.combine(
      PathOperation.difference,
      overlayPath,
      holePath,
    );
    canvas.drawPath(combined, Paint()..color = Colors.black.withValues(alpha: 0.72));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()
        ..color = AppTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _CoachMarkBubble extends StatelessWidget {
  const _CoachMarkBubble({
    required this.step,
    required this.index,
    required this.total,
    required this.isKu,
    required this.onNext,
    required this.onSkip,
  });

  final CoachMarkStep step;
  final int index;
  final int total;
  final bool isKu;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(step.icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isKu ? step.titleKu : step.titleTr,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${index + 1}/$total',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isKu ? step.descriptionKu : step.descriptionTr,
            style: TextStyle(
              color: AppTheme.textSubColor(context),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(isKu ? 'Derbas bike' : 'Atla'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                child: Text(
                  isLast
                      ? (isKu ? 'Temam' : 'Anladım')
                      : (isKu ? 'Pêş' : 'İleri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
