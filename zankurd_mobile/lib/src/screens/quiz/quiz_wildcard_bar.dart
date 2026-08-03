import 'package:flutter/material.dart';

import '../../models/wildcard.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
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
    required this.isUsed,
    required this.isAnswered,
    required this.isActive,
    required this.onTap,
    this.cantAfford = false,
    super.key,
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isUsed;
  final bool isAnswered;
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
    final canTap = widget.isEnabled;

    // Her durum ayrı bir ŞEY söyler; hepsini soluklaştırmak dördünü de
    // "bozuk" gösteriyordu (2026-08-03 görsel denetimi). Coin'i yetmeyen
    // joker bir kusur değil bir FİYAT: rengini ve fiyatını korur, yalnız
    // bir tık geri çekilir. Gerçekten edilgen olan tek durum, cevap
    // verildikten sonraki kilittir.
    final opacity = (widget.isEnabled || widget.isActive)
        ? 1.0
        : widget.cantAfford
        ? 0.82
        : widget.isUsed
        ? 0.55
        : 0.45;

    // 2026-07-24 canlı denetim: dört joker dolu renk bloğuydu ve quiz
    // ekranının en gürültülü öğesiydi — göz soruya değil alt bara gidiyordu.
    // Joker yardımcı araçtır: varsayılan hâli outline, yalnız etkinken dolu.
    final available = widget.isEnabled && !widget.cantAfford;

    final stateLabel = widget.isActive
        ? context.t(K.wildcardActive)
        : widget.isUsed
        ? context.t(K.wildcardUsed)
        : widget.isAnswered
        ? context.t(K.locked)
        : widget.cantAfford
        ? context.t(K.insufficientBalance)
        : null;

    final typeLabel = widget.type.label(widget.isKu);
    final displayLabel = stateLabel == null
        ? typeLabel
        : '$typeLabel • $stateLabel';

    final typeHint = switch (widget.type) {
      WildcardType.fiftyFifty => context.t(K.wildcardFiftyHint),
      WildcardType.audience => context.t(K.wildcardAudienceHint),
      WildcardType.doubleAnswer => context.t(K.wildcardDoubleHint),
      WildcardType.changeQuestion => context.t(K.wildcardChangeHint),
    };

    final tooltipMessage = stateLabel == null
        ? '$typeLabel • $typeHint'
        : '$typeLabel • $stateLabel';
    final hintMessage = stateLabel == null
        ? typeHint
        : '$typeHint • $stateLabel';

    // Coin'i yetmeyen joker kimliğini korur: gri kenarlık onu ölü
    // gösteriyordu, oysa satın alınabilir bir araç.
    final borderColor = widget.isActive
        ? AppTheme.brand
        : available
        ? baseColor.withValues(alpha: 0.55)
        : widget.cantAfford
        ? baseColor.withValues(alpha: 0.42)
        : AppTheme.borderColor(context);

    final bgColor = widget.isActive
        ? AppTheme.brand
        : available
        ? baseColor.withValues(alpha: AppTheme.isLight(context) ? 0.08 : 0.16)
        : null;

    final iconColor = widget.isActive
        ? Colors.white
        : available
        // Çipin zemini rengin kendi tonu; düz yüzeye göre ayarlanan
        // `readableAccent` orada bir tık yetersiz kalıyordu.
        ? AppColors.onAccentTint(context, baseColor)
        : widget.cantAfford
        ? AppColors.onAccentTint(context, baseColor)
        : AppTheme.textMutedColor(context);

    return Semantics(
      button: true,
      enabled: canTap,
      selected: widget.isActive,
      label: displayLabel,
      hint: hintMessage,
      excludeSemantics: true,
      onTap: canTap ? widget.onTap : null,
      child: Tooltip(
        message: tooltipMessage,
        child: GestureDetector(
          onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
          onTapUp: canTap ? (_) => setState(() => _pressed = false) : null,
          onTap: canTap
              ? () {
                  setState(() => _pressed = false);
                  widget.onTap();
                }
              : null,
          onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                // Erişilebilirlik: min 44px dokunma hedefi (WCAG).
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  color: bgColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                // Ad ve fiyat AYRI satırlarda. Tek satıra sıkıştırılıp
                // FittedBox ile küçültüldüğünde 375px genişlikte dört joker
                // etiketi ~8pt'ye düşüyor ve okunmuyordu (2026-07-25 canlı
                // denetimi).
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
                        widget.cantAfford || widget.isAnswered
                            ? AppIcons.lock
                            : widget.type.icon,
                        size: 12,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.type.label(widget.isKu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.05,
                        color: iconColor,
                      ),
                    ),
                    Text(
                      '${widget.type.coinCost}${context.t(K.coinAbbrev)}',
                      maxLines: 1,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        height: 1.05,
                        // %75 alfa hiyerarşi için kondu ama okunabilirliği
                        // yiyordu: bedel satırı 2.52-2.96:1 ölçüldü, yani
                        // oyuncu jokerin kaç coin olduğunu ancak yakından
                        // görüyordu (2026-07-27). Hiyerarşi zaten punto ve
                        // ağırlık farkında; alfaya gerek yok.
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
