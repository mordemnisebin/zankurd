import 'package:flutter/material.dart';
import '../providers/reduced_motion_provider.dart';
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final disabledColor = AppColors.disabledSurface(context);
    final backgroundColor = isEnabled ? AppTheme.brand : disabledColor;
    final reduceMotion = ReducedMotionProvider.isReducedIn(context);
    final animationDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 110);
    final hoverScale = !reduceMotion && isEnabled && _isHovered ? 1.01 : 1.0;

    return Semantics(
      button: true,
      label: widget.label,
      enabled: isEnabled,
      excludeSemantics: true,
      onTap: isEnabled ? widget.onPressed : null,
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
        onExit: (_) {
          if (_isHovered) setState(() => _isHovered = false);
        },
        child: AnimatedScale(
          scale: hoverScale,
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            child: Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: isEnabled ? widget.onPressed : null,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 48,
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
        ),
      ),
    );
  }
}
