import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/percent_format.dart';

/// Kültürel Modern ilerleme dili: dolgunun üzerinde kilim dokuma izi.
///
/// 2026-07-25 görsel denetimi: bu bileşenin adı ve belgesi bir kilim
/// motifi vaat ediyordu ("mercan dolgu üzerinde dokuma izi") ama gövdesi
/// düz renkli yuvarlak bir çubuktan ibaretti — uygulamanın kültürel görsel
/// kimliğini taşıyabilecek tek yer boş duruyordu. Desen artık çizilir.
///
/// Motif, Kurdî kilimlerinin en yaygın öğesi olan baklava dizisidir.
/// Amaç süs değil kimlik: desen okunurluğu bozmayacak kadar sessiz
/// tutulur ve yalnız dolu kısımda görünür, böylece ilerleme oranı yine
/// tek bakışta okunur.
class KilimProgressBar extends StatelessWidget {
  const KilimProgressBar({
    required this.value,
    this.height = 8,
    this.color = AppTheme.brand,
    this.trackColor,
    this.borderColor,
    super.key,
  });

  final double value;
  final double height;
  final Color color;

  /// Boş kısmın rengi. Verilmezse tema yüzeyi kullanılır.
  ///
  /// Renkli bir zeminin (ör. kategori hero'su) üstünde tema yüzeyi açık
  /// kaldığı için iz, dolgudan ayırt edilemiyor ve %0 ilerleme "tamamen
  /// dolu" gibi okunuyordu (2026-07-25). Renkli zeminlerde çağıran taraf
  /// yarı saydam bir iz vermelidir.
  final Color? trackColor;

  /// İz kenarlığı. Verilmezse tema kenarlığı kullanılır; renkli zeminde
  /// [Colors.transparent] geçilebilir.
  final Color? borderColor;

  /// Motifin görünür olabilmesi için gereken asgari yükseklik. Daha ince
  /// çubuklarda baklavalar birbirine girip dolguyu gri bir bulanıklığa
  /// çeviriyor; o durumda düz dolgu daha okunur.
  static const double _minHeightForPattern = 6;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      value: context.percentRatio(progress),
      child: Container(
        key: const ValueKey('kilim-progress-track'),
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: trackColor ?? AppTheme.surfaceHiColor(context),
          borderRadius: radius,
          border: Border.all(
            color:
                borderColor ??
                AppTheme.borderColor(context).withValues(alpha: 0.45),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          key: const ValueKey('kilim-progress-fill'),
          widthFactor: progress,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius),
            child: height >= _minHeightForPattern
                ? CustomPaint(
                    key: const ValueKey('kilim-progress-motif'),
                    painter: _KilimMotifPainter(height: height, fill: color),
                    size: Size.infinite,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Dolgunun üzerine baklava dizisi çizer.
///
/// Motif rengi dolgudan türetilir: koyu dolguda açık, açık dolguda koyu
/// bir ton kullanılır. Sabit beyaz kullanılsaydı beyaz dolgulu çubuklarda
/// (ör. renkli hero üzerindeki ilerleme) desen tamamen kaybolurdu —
/// uygulamanın başka yerlerindeki kontrast-farkında renk mantığıyla
/// (bkz. `AppColors.readableAccent`) aynı ilke.
class _KilimMotifPainter extends CustomPainter {
  const _KilimMotifPainter({required this.height, required this.fill});

  final double height;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Baklava genişliği yüksekliğe bağlanır: çubuk kalınlaştıkça motif de
    // büyür, oran sabit kalır. Sabit piksel kullanılsaydı ince çubukta
    // desen sıkışır, kalın çubukta seyrelirdi.
    final unit = height * 0.9;
    final isLightFill = fill.computeLuminance() > 0.6;
    final paint = Paint()
      ..color = (isLightFill ? Colors.black : Colors.white).withValues(
        alpha: isLightFill ? 0.14 : 0.22,
      )
      ..style = PaintingStyle.fill;

    final halfHeight = size.height / 2;
    // Sol kenardan yarım birim içeride başlanır ki ilk baklava dolgunun
    // başlangıcında yarım kalmasın.
    for (var x = unit / 2; x < size.width + unit; x += unit) {
      final diamond = Path()
        ..moveTo(x, 0)
        ..lineTo(x + unit / 2, halfHeight)
        ..lineTo(x, size.height)
        ..lineTo(x - unit / 2, halfHeight)
        ..close();
      canvas.drawPath(diamond, paint);
    }
  }

  @override
  bool shouldRepaint(_KilimMotifPainter oldDelegate) =>
      oldDelegate.height != height || oldDelegate.fill != fill;
}
