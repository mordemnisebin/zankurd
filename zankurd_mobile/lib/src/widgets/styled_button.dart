import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GeometricGradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const GeometricGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<GeometricGradientButton> createState() =>
      _GeometricGradientButtonState();
}

class _GeometricGradientButtonState extends State<GeometricGradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final disabledColor = AppColors.disabledSurface(context);

    final foregroundColor = isEnabled
        ? AppTheme.lightTextPrimary
        : AppTheme.textMutedColor(context);
    final shadowColor = isEnabled
        ? AppTheme.primaryGradientStart.withValues(alpha: 0.55)
        : disabledColor.withValues(alpha: 0.6);

    const double shadowHeight = 4.0;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: 48,
        margin: EdgeInsets.only(
          top: _isPressed ? shadowHeight : 0,
          bottom: _isPressed ? 0 : shadowHeight,
        ),
        decoration: BoxDecoration(
          gradient: isEnabled
              ? AppTheme.accentGradient
              : LinearGradient(colors: [disabledColor, disabledColor]),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.button(shadowColor, pressed: _isPressed),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: foregroundColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
