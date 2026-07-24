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

    // 2026-07-24 canlı denetim: dört joker dolu renk bloğuydu ve quiz
    // ekranının en gürültülü öğesiydi — göz soruya değil alt bara gidiyordu.
    // Joker yardımcı araçtır: varsayılan hâli outline, yalnız etkinken dolu.
    final available = widget.isEnabled && !widget.cantAfford;

    final borderColor = widget.isActive
        ? AppTheme.brand
        : available
        ? baseColor.withValues(alpha: 0.55)
        : AppTheme.borderColor(context);

    final bgColor = widget.isActive
        ? AppTheme.brand
        : available
        ? baseColor.withValues(alpha: AppTheme.isLight(context) ? 0.08 : 0.16)
        : null;

    final iconColor = widget.isActive
        ? Colors.white
        : available
        ? AppColors.readableAccent(context, baseColor)
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
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              // Erişilebilirlik: min 44px dokunma hedefi (WCAG).
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: bgColor ?? Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: borderColor, width: 1.2),
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
                        color: widget.isActive
                            ? Colors.white.withValues(alpha: 0.24)
                            : iconColor.withValues(alpha: 0.14),
                      ),
                      child: Icon(
                        widget.cantAfford ? AppIcons.lock : widget.type.icon,
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
                        fontSize: 11,
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
