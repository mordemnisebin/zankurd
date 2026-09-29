import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_glyphs.dart';

enum _SahneButtonKind { primary, secondary, text }

/// Şahnê düğmesi — maketteki "1 · Düğme".
///
/// * [SahneButton.primary] — Agir dolgu, koyu metin, isteğe bağlı ok,
///   ekrandaki TEK bulanık gölge (`0 8 24 -8`). Ekranda tek birincil.
///   Uygulamanın `FilledButton` temasına dayanır.
/// * [SahneButton.secondary] — Kulis (`s2`) tonu, kenarsız.
/// * [SahneButton.text] — Agir metni (`actTx`) + chevron, 44 dokunma alanı.
/// * Pasif — `onPressed: null`: opaklık değil Perde (`s1`) + üçüncül metin
///   (`tx3`), gündüzde 1 px kenar; gölge yok.
///
/// Kural: tek boy 52 (metin düğmesi 44); kart içinde ve alt perdede
/// [expand] ile tam genişlik. Metin sarar — büyük yazı ölçeğinde düğme
/// uzar, kesilmez. Basınca 2 px çöker (hareketi azaltta yok); odakta
/// Halka 2.
class SahneButton extends StatelessWidget {
  const SahneButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.arrow = true,
    this.expand = false,
    this.semanticLabel,
  }) : _kind = _SahneButtonKind.primary;

  const SahneButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.arrow = false,
    this.expand = false,
    this.semanticLabel,
  }) : _kind = _SahneButtonKind.secondary;

  const SahneButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.arrow = true,
    this.semanticLabel,
  }) : _kind = _SahneButtonKind.text,
       icon = null,
       expand = false;

  final _SahneButtonKind _kind;
  final String label;

  /// `null` → pasif.
  final VoidCallback? onPressed;

  /// Etiketin solundaki ikon (Lucide).
  final IconData? icon;

  /// Birincilde sağda ok (→), metin düğmesinde chevron (›).
  final bool arrow;

  /// Tam genişlik.
  final bool expand;

  /// Ekran okuyucu için farklı bir söz gerekiyorsa.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final enabled = onPressed != null;
    final isText = _kind == _SahneButtonKind.text;
    final iconSize = isText ? 16.0 : 20.0;
    final gap = isText ? SahneSpace.x1 : SahneSpace.x2;
    // Tam genişlikte yan boşluk 12 (maketteki `.sh-2btn`): iki düğme yan
    // yana durduğunda "Kelime kartları" tek satıra sığar.
    final hPad = expand ? SahneSpace.x3 : SahneSpace.x5;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: iconSize), SizedBox(width: gap)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (arrow) ...[
          SizedBox(width: gap),
          Icon(
            isText ? AppIcons.chevronRight : AppIcons.arrowRight,
            size: iconSize,
          ),
        ],
      ],
    );

    WidgetStateProperty<BorderSide?> side(BorderSide rest) =>
        WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.focused)) {
            return BorderSide(
              color: t.tx,
              width: SahneRing.r2,
              strokeAlign: BorderSide.strokeAlignInside,
            );
          }
          if (s.contains(WidgetState.disabled)) {
            return BorderSide(
              color: t.edge,
              strokeAlign: BorderSide.strokeAlignInside,
            );
          }
          return rest;
        });

    Widget button;
    switch (_kind) {
      case _SahneButtonKind.primary:
        button = FilledButton(
          onPressed: onPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(52, 52)),
            side: side(BorderSide.none),
            textStyle: const WidgetStatePropertyAll(SahneType.button),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: hPad, vertical: SahneSpace.x3),
            ),
          ),
          child: content,
        );
        if (enabled) {
          button = DecoratedBox(
            decoration: ShapeDecoration(
              shape: SahneShape.m,
              shadows: [
                BoxShadow(
                  color: t.actShadow,
                  offset: const Offset(0, 8),
                  blurRadius: t.actShadowBlur,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: button,
          );
        }
      case _SahneButtonKind.secondary:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: t.s2,
            foregroundColor: t.tx,
            disabledBackgroundColor: t.s1,
            disabledForegroundColor: t.tx3,
            minimumSize: const Size(52, 52),
            textStyle: SahneType.button,
            shape: SahneShape.m,
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: SahneSpace.x3,
            ),
          ).copyWith(side: side(BorderSide.none)),
          child: content,
        );
      case _SahneButtonKind.text:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: t.actTx,
            disabledForegroundColor: t.tx3,
            minimumSize: const Size(44, 44),
            textStyle: SahneType.captionStrong,
            shape: SahneShape.m,
            padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x1),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(side: side(BorderSide.none)),
          child: content,
        );
    }

    if (expand) button = SizedBox(width: double.infinity, child: button);
    button = SahnePressSink(enabled: enabled, child: button);
    if (semanticLabel != null) {
      button = Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        button: true,
        enabled: enabled,
        onTap: onPressed,
        child: button,
      );
    }
    return button;
  }
}

/// Joker düğmesi — ikincilin kompakt çeşidi (maketteki `.sh-jk`).
///
/// 52 boy, Kulis tonu, ortada ikon + jeton glifi + fiyat (Zêr metni). Adı
/// ekranda yazmaz: ekran okuyucu "ad, fiyat"ı okur, uzun basışta ipucu
/// olarak görünür. Pasif joker (`onPressed: null`): Perde + üçüncül ikon,
/// fiyat gizli, opaklık yok. Dar ekranda ve büyük yazıda içerik
/// sığdırılarak küçülür (taşmaz).
class SahneJokerButton extends StatelessWidget {
  const SahneJokerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.price,
    required this.onPressed,
    this.semanticLabel,
  });

  final IconData icon;

  /// Jokerin adı (ör. "Nîv bi Nîv"): Semantics ve uzun basış ipucu.
  final String label;
  final int price;
  final VoidCallback? onPressed;

  /// Varsayılan: "ad, fiyat".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final enabled = onPressed != null;
    final fg = enabled ? t.tx : t.tx3;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel ?? '$label, $price',
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        triggerMode: TooltipTriggerMode.longPress,
        excludeFromSemantics: true,
        child: SahnePressSink(
          enabled: enabled,
          child: SahneTappable(
            shape: SahneShape.m,
            color: enabled ? t.s2 : t.s1,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x1),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: fg),
                        if (enabled) ...[
                          const SizedBox(width: SahneSpace.x1),
                          const SahneGlyph(SahneGlyphKind.coin, size: 16),
                          const SizedBox(width: SahneSpace.x1),
                          Text(
                            '$price',
                            style: SahneType.captionStrong.copyWith(
                              color: t.goldTx,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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

/// Joker dizisi: eşit genişlikte jokerler, 8 aralık (maketteki
/// `.sh-jkrow`). Oyun sahnesinin alt perdesinde cevaptan önce durur.
class SahneJokerBar extends StatelessWidget {
  const SahneJokerBar({super.key, required this.jokers});

  final List<Widget> jokers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < jokers.length; i++) ...[
          if (i > 0) const SizedBox(width: SahneSpace.x2),
          Expanded(child: jokers[i]),
        ],
      ],
    );
  }
}
