import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/percent_format.dart';

/// Kültürel Modern ilerleme dili: mercan dolgu üzerinde dokuma izi.
class KilimProgressBar extends StatelessWidget {
  const KilimProgressBar({
    required this.value,
    this.height = 8,
    this.color = AppTheme.brand,
    super.key,
  });

  final double value;
  final double height;
  final Color color;

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
          color: AppTheme.surfaceHiColor(context),
          borderRadius: radius,
          border: Border.all(
            color: AppTheme.borderColor(context).withValues(alpha: 0.45),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          key: const ValueKey('kilim-progress-fill'),
          widthFactor: progress,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}
