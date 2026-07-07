import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Button variants for [ZankurdButton].
enum ZankurdButtonVariant {
  /// Accent-filled button — primary CTA.
  filled,

  /// Outlined button — secondary action.
  outlined,

  /// Text-only ghost button — minimal emphasis.
  ghost,
}

/// Reusable button component using ZanKurd's design tokens.
///
/// Respects the theme's [FilledButtonThemeData] and
/// [OutlinedButtonThemeData], keeping a minimum 44 px touch target.
class ZankurdButton extends StatelessWidget {
  const ZankurdButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = ZankurdButtonVariant.filled,
    this.expanded = false,
  });

  /// Button label text.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Tap callback. When `null` the button is disabled.
  final VoidCallback? onPressed;

  /// Visual variant.
  final ZankurdButtonVariant variant;

  /// Whether the button should fill available width.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(label),
            ],
          )
        : Text(label);

    switch (variant) {
      case ZankurdButtonVariant.filled:
        return _Filled(label: label, icon: icon, onPressed: onPressed, expanded: expanded, child: child);
      case ZankurdButtonVariant.outlined:
        return _Outlined(label: label, icon: icon, onPressed: onPressed, expanded: expanded, child: child);
      case ZankurdButtonVariant.ghost:
        return _Ghost(label: label, icon: icon, onPressed: onPressed, expanded: expanded, child: child);
    }
  }
}

class _Filled extends StatelessWidget {
  const _Filled({required this.label, this.icon, this.onPressed, required this.expanded, required this.child});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : null,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20) : null,
        label: Text(label),
      ),
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined({required this.label, this.icon, this.onPressed, required this.expanded, required this.child});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20) : null,
        label: Text(label),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, this.icon, this.onPressed, required this.expanded, required this.child});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fgColor = AppTheme.textPrimaryOf(context);
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: 48, // min 44 px touch target'a uygun
      child: TextButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20, color: onPressed != null ? fgColor : AppTheme.textMuted) : null,
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: onPressed != null ? fgColor : AppTheme.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
        ),
      ),
    );
  }
}
