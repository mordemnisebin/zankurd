import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Reusable metric tile — icon + value + label.
///
/// Uses [AppTheme.statCard] for the container decoration.
/// Designed for use on Quiz Result, Profile, Home, and similar screens.
class ZankurdMetricTile extends StatelessWidget {
  const ZankurdMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  /// Leading icon.
  final IconData icon;

  /// Large metric value text (e.g. "85%").
  final String value;

  /// Small label below the value (e.g. "Accuracy").
  final String label;

  /// Accent colour for the icon and border tint (defaults to [AppTheme.accent]).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.accent;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      decoration: AppTheme.statCard(context, accent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: accent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
