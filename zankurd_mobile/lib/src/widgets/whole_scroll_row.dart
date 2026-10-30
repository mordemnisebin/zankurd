import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Kaydırıcının alt sınırına sığmayan satırı yarım göstermek yerine gizler.
/// Yerini koruduğu için kaydırınca satırın tamamı görünür. Ekrandan uzun
/// satırlar erişilebilir kalmak için normal biçimde kaydırılır.
class WholeScrollRow extends StatelessWidget {
  const WholeScrollRow({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Pencere/klavye boyutu değişip kaydırma konumu aynı kalsa da
    // önbellekteki kırpma yeniden hesaplanmalıdır.
    MediaQuery.of(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;
    return ClipRect(clipper: _WholeRowClipper(context, position), child: child);
  }
}

class _WholeRowClipper extends CustomClipper<Rect> {
  _WholeRowClipper(this.context, ScrollPosition position)
    : super(reclip: position);

  final BuildContext context;

  @override
  Rect getClip(Size size) {
    final box = context.findRenderObject();
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
    if (box is RenderBox && viewport is RenderBox) {
      final viewportBox = viewport as RenderBox;
      final bounds = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & size,
      );
      if (size.height <= viewportBox.size.height &&
          bounds.bottom > viewportBox.size.height + 0.5) {
        return Rect.zero;
      }
    }
    return Offset.zero & size;
  }

  @override
  bool shouldReclip(_WholeRowClipper oldClipper) => true;
}
