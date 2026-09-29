import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sahne/sahne.dart';

/// Genel bilgi yüzeyi.
///
/// 2026-09-29 Şahnê: görünüş [SahneSurfaceCard] ile aynıdır — Perde (`s1`),
/// L pah; gecede kenarsız (katman tonla ayrılır), gündüzde 1 px kenar
/// (`edge`). Bulanık gölge yok. Eski parametreler geriye uyum için kalır
/// ama ham renk üretmez:
///
/// * [color] — doygun bir renk verilirse rolüne ([sahneRoleFor]) çevrilir
///   ve rolün ton zemini (`roleTint`) boyanır; nötr bir yüzey rengi
///   verilirse Perde, yükseltilmiş yüzey (`surfaceHi`) verilirse Kulis.
/// * [gradient] — koyu kahraman yüzeyleri (içinde açık metin) gece sahne
///   kartı zeminiyle, altın ödül yüzeyi Zêr dolgusuyla çizilir; içerik
///   her iki durumda da kendi kontrastını korur.
/// * [borderRadius] ve [cardType] yok sayılır: şekil her zaman L pahtır.
class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(SahneSpace.x4),
    this.gradient,
    this.color,
    this.borderRadius,
    this.cardType = CardType.secondary,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final BorderRadius? borderRadius;

  /// Verilirse panel dokunulabilir olur; dalga pah şeklinden taşmaz.
  final VoidCallback? onTap;

  /// Geriye uyum; Şahnê'de her panel aynı yüzey kartıdır.
  final CardType cardType;

  /// Dokunulabilir panelin ekran okuyucuda tek bir eylem olarak duyurulması.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final panel = SizedBox(width: double.infinity, child: _surface(context));
    if (onTap == null && semanticLabel == null) return panel;
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap == null ? null : true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: panel,
    );
  }

  Widget _surface(BuildContext context) {
    final t = SahneTokens.of(context);
    final g = gradient;
    if (g != null && g.colors.isNotEmpty) {
      final role = sahneRoleFor(g.colors.first);
      if (role == SahneRole.gold) {
        // Altın ödül yüzeyi: içerik zaten koyu mürekkeple yazılmış.
        return SahneTappable(
          shape: SahneShape.l,
          color: t.gold,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        );
      }
      // Koyu kahraman yüzeyi: gece sahne kartı zemini + rol radyali. İçerik
      // gündüz temasında da gece belirteçlerini alır (bkz. [SahneStage]).
      final stage = ClipPath(
        clipper: const ShapeBorderClipper(shape: SahneShape.l),
        child: CustomPaint(
          painter: SahneStagePainter(
            race: role == SahneRole.race,
            glow: role == SahneRole.race
                ? null
                : SahneTokens.night.roleGlow(role),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: SahneShape.l,
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      );
      return SahneStage(stage: AppTheme.stage, child: stage);
    }

    return SahneTappable(
      shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      color: _fill(context, t),
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
  }

  Color _fill(BuildContext context, SahneTokens t) {
    final c = color;
    if (c == null) return t.s1;
    final role = sahneRoleFor(c);
    if (role != SahneRole.neutral) return t.roleTint(role);
    // Nötr bir yüzey rengi: eski "yükseltilmiş yüzey" Kulis'e, geri kalan
    // her şey Perde'ye karşılık gelir.
    return c.withValues(alpha: 1) ==
            AppTheme.surfaceHiColor(context).withValues(alpha: 1)
        ? t.s2
        : t.s1;
  }
}
