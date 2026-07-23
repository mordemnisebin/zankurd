import 'package:flutter/material.dart';

import '../../models/wildcard.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';

/// Quiz joker butonu (50/50, Seyirci, Çift Cevap, Soru Değiştir).
///
/// Aktif/kullanılmış/satın alınamaz durumlarını kendi içinde çizer;
/// basılı tutma animasyonu ve tooltip dahildir.
class WildcardButton extends StatefulWidget {
  const WildcardButton({
    required this.type,
    required this.isKu,
    required this.isEnabled,
    required this.isActive,
    required this.onTap,
    this.cantAfford = false,
    super.key,
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isActive;
  final bool cantAfford;
  final VoidCallback onTap;

  @override
  State<WildcardButton> createState() => _WildcardButtonState();
}

class _WildcardButtonState extends State<WildcardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.type.themeColor;

    final opacity = (widget.isEnabled || widget.isActive)
        ? 1.0
        : widget.cantAfford
        ? 0.45
        : 0.35;

    final borderColor = widget.cantAfford || (!widget.isEnabled && !widget.isActive)
        ? AppTheme.borderColor(context)
        : Colors.transparent;

    final bgColor = widget.isActive
        ? AppTheme.brand
        : widget.cantAfford
        ? AppTheme.surfaceHiColor(context).withValues(alpha: 0.4)
        : widget.isEnabled
        ? baseColor
        : null;

    final iconColor = (widget.isEnabled || widget.isActive)
        ? Colors.white
        : AppTheme.textMutedColor(context);

    return Tooltip(
      message: widget.type.label(widget.isKu),
      child: GestureDetector(
        onTapDown: widget.isEnabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.isEnabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: widget.isEnabled
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: opacity,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              // Erişilebilirlik: min 44px dokunma hedefi (WCAG).
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: bgColor ?? Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.isEnabled || widget.isActive)
                            ? Colors.white.withValues(alpha: 0.22)
                            : iconColor.withValues(alpha: 0.10),
                      ),
                      child: Icon(
                        widget.cantAfford
                            ? AppIcons.lock
                            : widget.type.icon,
                        size: 12,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Ad + fiyat tek satırda: uzun joker adları ("Pirsê
                    // Biguhere") iki satıra düşüp taşırıyordu.
                    Text(
                      '${widget.type.label(widget.isKu)} · ${widget.type.coinCost}c',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        height: 1.0,
                        color: iconColor,
                      ),
                    ),
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
