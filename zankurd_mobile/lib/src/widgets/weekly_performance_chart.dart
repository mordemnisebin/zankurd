import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/sahne.dart';
import 'sahne/sahne_foundation.dart';
import '../utils/error_reporter.dart';

/// Y ekseni adımı: 1, 2, 5, 10, 20, 50… dizisinden, [maxVal]'i en çok beş
/// aralıkta örten en küçük tamsayı adım. Etiketler hep tam sayıdır ve
/// eşit aralıklıdır.
@visibleForTesting
int niceStep(int maxVal) {
  var base = 1;
  while (true) {
    for (final m in const [1, 2, 5]) {
      final step = base * m;
      if ((maxVal / step).ceil() <= 5) return step;
    }
    base *= 10;
  }
}

class WeeklyPerformanceChart extends StatelessWidget {
  const WeeklyPerformanceChart({
    required this.history,
    required this.isKu,
    super.key,
  });

  final Map<String, Map<String, int>> history;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    // 2026-09-29 Şahnê: doğru Rast metni (`okTx`), yanlış Şaş metni
    // (`errTx`) — iki temada da zemine karşı okunan durum tonları; çubuklar
    // S pahlı; eksen yazısı Açıklama (Onest), üçüncül metin; ızgara `line`.
    final t = SahneTokens.of(context);
    final textColor = t.tx;
    final mutedTextColor = t.tx3;

    // Find the max total answers in a single day to scale the chart
    var maxVal = 5; // Default minimum scale
    history.forEach((_, data) {
      final total = (data['correct'] ?? 0) + (data['wrong'] ?? 0);
      if (total > maxVal) {
        maxVal = total;
      }
    });

    // 2026-09-30 simülatör: eksen 4 eşit aralığa bölünüyordu ve etiket
    // yuvarlanıyordu: en büyük değer 5 iken 0, 1, 3, 4, 5 çıkıyor ("2"
    // yok, 1,25 -> 1 ve 2,5 -> 3), eksen yalan söylüyordu. Sayılar artık
    // hep tamsayı adımla ilerler; en büyük değer adımın katına yukarı
    // yuvarlanır. Kusur yalnız 4'e bölünmeyen tavanlarda görünürdü;
    // varsayılan tavan (5) tam bu durumdu ama kimse eksene bakmıyordu.
    final step = niceStep(maxVal);
    final gridCount = (maxVal / step).ceil();
    maxVal = step * gridCount;

    final gridLineColor = t.line;
    Widget chart(double progress) => SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          history: history,
          maxVal: maxVal,
          gridCount: gridCount,
          progress: progress,
          isKu: isKu,
          gridLineColor: gridLineColor,
          labelColor: mutedTextColor,
          correctColor: t.okTx,
          wrongColor: t.errTx,
        ),
      ),
    );

    // Çubuk büyümesi süsüdür. Tercih açıkken ilk karede tam boyda
    // durur; yoksa profilin en hareketli yüzeyi ayarı yok sayar.
    final reduceMotion =
        ReducedMotionProvider.isReducedIn(context) ||
        sahneMotionReduced(context);
    final chartArea = reduceMotion
        ? chart(1.0)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuart,
            builder: (context, progress, child) => chart(progress),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _LegendItem(
              color: t.okTx,
              label: Tr.forKu(K.correct, isKu),
              textColor: textColor,
            ),
            const SizedBox(width: SahneSpace.x4),
            _LegendItem(
              color: t.errTx,
              label: Tr.forKu(K.wrong, isKu),
              textColor: textColor,
            ),
          ],
        ),
        const SizedBox(height: SahneSpace.x4),
        chartArea,
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 12,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: color, shape: SahneShape.s),
          ),
        ),
        const SizedBox(width: SahneSpace.x2),
        Text(label, style: SahneType.caption.copyWith(color: textColor)),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.history,
    required this.maxVal,
    required this.gridCount,
    required this.progress,
    required this.isKu,
    required this.gridLineColor,
    required this.labelColor,
    required this.correctColor,
    required this.wrongColor,
  });

  final Map<String, Map<String, int>> history;
  final int maxVal;
  final int gridCount;
  final double progress;
  final bool isKu;
  final Color gridLineColor;
  final Color labelColor;
  final Color correctColor;
  final Color wrongColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double labelAreaWidth = 24.0;
    const double labelAreaHeight = 24.0;
    final double chartWidth = size.width - labelAreaWidth;
    final double chartHeight = size.height - labelAreaHeight;

    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw Grid Lines and Y-Axis labels
    for (int i = 0; i <= gridCount; i++) {
      final double y = chartHeight * (1.0 - (i / gridCount));

      // Draw grid line
      canvas.drawLine(
        Offset(labelAreaWidth, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Draw Y label (value representation)
      final labelVal = maxVal ~/ gridCount * i;
      textPainter.text = TextSpan(
        text: '$labelVal',
        // Boyayıcı temayı görmez; aile yazılmazsa eksen etiketleri sistem
        // yazı tipiyle çizilir ve grafik ekranın geri kalanına yabancı
        // görünür (2026-07-26). Biçem SahneType'tan.
        style: SahneType.caption.copyWith(
          fontFamily: SahneType.text,
          color: labelColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    // 2. Draw Bars and X-Axis labels
    final List<String> keys = history.keys.toList();
    final double barWidth = math.min(18.0, chartWidth / (keys.length * 2.0));
    final double spacing =
        (chartWidth - (barWidth * keys.length)) / (keys.length + 1);

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final data = history[key] ?? {'correct': 0, 'wrong': 0};
      final correctCount = data['correct'] ?? 0;
      final wrongCount = data['wrong'] ?? 0;

      final double x = labelAreaWidth + spacing + i * (barWidth + spacing);

      // Stacked Bar Heights
      final double correctHeight =
          (correctCount / maxVal) * chartHeight * progress;
      final double wrongHeight = (wrongCount / maxVal) * chartHeight * progress;

      // Draw Correct part (Bottom part)
      // Şahnê S pahı (yarıçap değil): yığılan iki parçanın birleştiği
      // kenar düz kalır.
      Path bar(Rect rect, {required bool top, required bool bottom}) {
        const bevel = Radius.circular(SahneShape.sValue);
        return BeveledRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: top ? bevel : Radius.zero,
            topRight: top ? bevel : Radius.zero,
            bottomLeft: bottom ? bevel : Radius.zero,
            bottomRight: bottom ? bevel : Radius.zero,
          ),
        ).getOuterPath(rect);
      }

      if (correctHeight > 0) {
        canvas.drawPath(
          bar(
            Rect.fromLTWH(
              x,
              chartHeight - correctHeight,
              barWidth,
              correctHeight,
            ),
            top: wrongHeight == 0,
            bottom: true,
          ),
          Paint()..color = correctColor,
        );
      }

      // Draw Wrong part (Top part, stacked on top of correct part)
      if (wrongHeight > 0) {
        canvas.drawPath(
          bar(
            Rect.fromLTWH(
              x,
              chartHeight - correctHeight - wrongHeight,
              barWidth,
              wrongHeight,
            ),
            top: true,
            bottom: correctHeight == 0,
          ),
          Paint()..color = wrongColor,
        );
      }

      // Draw X Label (Weekday)
      int weekday = 1;
      try {
        weekday = DateTime.parse(key).weekday;
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'weekly_performance_chart');
      }

      final weekdayLabel = _getWeekdayAbbreviation(weekday, isKu);
      textPainter.text = TextSpan(
        text: weekdayLabel,
        // Boyayıcı temayı görmez; aile yazılmazsa eksen etiketleri sistem
        // yazı tipiyle çizilir ve grafik ekranın geri kalanına yabancı
        // görünür (2026-07-26). Biçem SahneType'tan.
        style: SahneType.caption.copyWith(
          fontFamily: SahneType.text,
          color: labelColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 4),
      );
    }
  }

  String _getWeekdayAbbreviation(int weekday, bool isKu) {
    if (isKu) {
      return switch (weekday) {
        1 => 'Du',
        2 => 'Sê',
        3 => 'Ça',
        4 => 'Pê',
        5 => 'În',
        6 => 'Şe',
        7 => 'Ye',
        _ => '',
      };
    } else {
      return switch (weekday) {
        1 => 'Pt',
        2 => 'Sa',
        3 => 'Ça',
        4 => 'Pe',
        5 => 'Cu',
        6 => 'Ct',
        7 => 'Pz',
        _ => '',
      };
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.history != history ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.isKu != isKu;
  }
}
