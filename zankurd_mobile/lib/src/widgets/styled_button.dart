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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final isPressed = isEnabled && _isPressed;
    final isHovered = isEnabled && _isHovered;
    final disabledColor = AppColors.disabledSurface(context);

    final shadowColor = isEnabled
        ? AppTheme.primaryGradientStart.withValues(alpha: 0.55)
        : disabledColor.withValues(alpha: 0.6);

    const double shadowHeight = 4.0;

    return Semantics(
      button: true,
      label: widget.label,
      enabled: isEnabled,
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
        onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
        child: GestureDetector(
          onTapDown: isEnabled
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: isEnabled
              ? (_) {
                  setState(() => _isPressed = false);
                  widget.onPressed?.call();
                }
              : null,
          onTapCancel: isEnabled
              ? () => setState(() => _isPressed = false)
              : null,
          child: AnimatedScale(
            scale: isHovered ? 1.01 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              height: 48,
              margin: EdgeInsets.only(
                top: isPressed ? shadowHeight : 0,
                bottom: isPressed ? 0 : shadowHeight,
              ),
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? AppTheme.accentGradient
                    : LinearGradient(colors: [disabledColor, disabledColor]),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.button(shadowColor, pressed: isPressed),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (widget.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else ...[
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        // 2026-07-22 canlı UX denetimi: CTA çift okuma düzeltmesi
                        child: ExcludeSemantics(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
