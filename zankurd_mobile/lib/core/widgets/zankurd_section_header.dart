import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Reusable section header with a coloured left accent bar.
///
/// Supports an optional subtitle and trailing action button.
/// Safe against overflow via [Expanded] on the text column.
class ZankurdSectionHeader extends StatelessWidget {
  const ZankurdSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accentColor,
  });

  /// Section title text.
  final String title;

  /// Optional descriptive subtitle below the title.
  final String? subtitle;

  /// Optional action button label (trailing).
  final String? actionLabel;

  /// Callback when the trailing action is tapped.
  final VoidCallback? onAction;

  /// Left accent bar colour (defaults to [AppTheme.accent]).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left accent bar
        Container(
          width: 4,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: AppTheme.sectionAccent(accent),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Title + subtitle (safe against overflow)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        // Optional trailing action
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
