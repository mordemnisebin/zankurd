import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';

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
    final textColor = AppTheme.textPrimaryColor(context);
    final mutedTextColor = AppTheme.textMutedColor(context);

    // Find the max total answers in a single day to scale the chart
    int maxVal = 5; // Default minimum scale
    history.forEach((_, data) {
      final total = (data['correct'] ?? 0) + (data['wrong'] ?? 0);
      if (total > maxVal) {
        maxVal = total;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _LegendItem(
              color: AppTheme.correct,
              label: isKu ? 'Rast' : 'Doğru',
              textColor: textColor,
            ),
            const SizedBox(width: 14),
            _LegendItem(
              color: AppTheme.wrong,
              label: isKu ? 'Şaş' : 'Yanlış',
              textColor: textColor,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Chart Area
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutQuart,
          builder: (context, progress, child) {
            return SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(
                  history: history,
                  maxVal: maxVal,
                  progress: progress,
                  isKu: isKu,
                  gridLineColor: AppTheme.borderColor(
                    context,
                  ).withValues(alpha: 0.5),
                  labelColor: mutedTextColor,
                  correctColor: AppTheme.correct,
                  wrongColor: AppTheme.wrong,
                ),
              ),
            );
          },
        ),
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.history,
    required this.maxVal,
    required this.progress,
    required this.isKu,
    required this.gridLineColor,
    required this.labelColor,
    required this.correctColor,
    required this.wrongColor,
  });

  final Map<String, Map<String, int>> history;
  final int maxVal;
  final double progress;
  final bool isKu;
  final Color gridLineColor;
  final Color labelColor;
  final Color correctColor;
  final Color wrongColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double labelAreaWidth = 24.0;
    final double labelAreaHeight = 24.0;
    final double chartWidth = size.width - labelAreaWidth;
    final double chartHeight = size.height - labelAreaHeight;

    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw Grid Lines and Y-Axis labels
    final int gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final double y = chartHeight * (1.0 - (i / gridCount));

      // Draw grid line
      canvas.drawLine(
        Offset(labelAreaWidth, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Draw Y label (value representation)
      final labelVal = (maxVal * (i / gridCount)).round();
      textPainter.text = TextSpan(
        text: '$labelVal',
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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
      if (correctHeight > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x,
            chartHeight - correctHeight,
            barWidth,
            correctHeight,
          ),
          topLeft: wrongHeight == 0 ? const Radius.circular(4) : Radius.zero,
          topRight: wrongHeight == 0 ? const Radius.circular(4) : Radius.zero,
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = correctColor);
      }

      // Draw Wrong part (Top part, stacked on top of correct part)
      if (wrongHeight > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x,
            chartHeight - correctHeight - wrongHeight,
            barWidth,
            wrongHeight,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
          bottomLeft: correctHeight == 0
              ? const Radius.circular(4)
              : Radius.zero,
          bottomRight: correctHeight == 0
              ? const Radius.circular(4)
              : Radius.zero,
        );
        canvas.drawRRect(rect, Paint()..color = wrongColor);
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
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 6),
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
        oldDelegate.isKu != isKu;
  }
}
