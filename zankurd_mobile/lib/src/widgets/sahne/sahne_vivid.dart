import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_list_row.dart';
import 'sahne_painters.dart';

/// Renkli kahraman yüzeyleri (2026-10-20 renk ve canlılık işi).
///
/// ## Kusur
///
/// Sadeleştirme turları yarış merkezinin kahramanını beyaz bir yüzey
/// kartına indirmişti; yarış modunun rengi (Boyax) ekranda yalnız ikon
/// kutularındaki soluk bir tondu. Rakiplerde (TRT Bil Bakalım, Kahoot) mod
/// ekranın kahramanı olarak kendi renginde DOLUDUR.
///
/// ## Karar
///
/// [SahneRaceHeroSurface]: Boyax → koyu gradyan, sağ üst köşede silik baklava
/// (kilim) motifi, altta kilim şeridi. İçerik (üst etiket, manşet, çipler,
/// birincil Agir düğme) çağıranın. Renkler [SahneTokens] ve [SahneVivid]'den
/// gelir; ham renk yok.
///
/// [SahneHeroSurface] aynı yüzeyin ROL rengindeki hâlidir (2026-10-20, B
/// aşaması): sosyal Nîl (arkadaş, oda), öğrenme Zimrût, yarış Boyax.
class SahneHeroSurface extends StatelessWidget {
  const SahneHeroSurface({
    super.key,
    required this.child,
    this.role = SahneRole.race,
    this.kilimKey,
    this.kilim = true,
  });

  final Widget child;
  final SahneRole role;

  /// Alt kilim şeridi çizilsin mi.
  final bool kilim;

  /// Alt kilim şeridinin anahtarı (testler şeridi bununla sayar).
  final Key? kilimKey;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: SahneShape.l),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              t.roleFill(role) ?? t.raceFill,
              t.roleDeep(role) ?? t.raceDeep,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Silik baklava motifi: beyaz %9, sağ üst köşeden taşar.
            const PositionedDirectional(
              end: -30,
              top: -26,
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 150,
                  child: CustomPaint(painter: _HeroMotifPainter()),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                // Kilim imzası: ekranda TEK; yükseklik ≤ 12 pt.
                if (kilim)
                  SahneKilimStrip(
                    key: kilimKey,
                    color: SahneVivid.heroKilim,
                    height: 8,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yarış (Boyax) kahramanı: [SahneHeroSurface]'in yarış rolü.
class SahneRaceHeroSurface extends SahneHeroSurface {
  const SahneRaceHeroSurface({super.key, required super.child, super.kilimKey})
    : super(role: SahneRole.race);
}

/// Boyax kahramanın köşesindeki silik iç içe baklava motifi.
class _HeroMotifPainter extends CustomPainter {
  const _HeroMotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final line = Paint()
      ..color = SahneVivid.heroMotif
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    Path diamond(double r) => Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas
      ..drawPath(diamond(size.width * 0.45), line)
      ..drawPath(diamond(size.width * 0.30), line)
      ..drawPath(
        diamond(size.width * 0.15),
        Paint()..color = SahneVivid.heroMotif,
      );
  }

  @override
  bool shouldRepaint(_HeroMotifPainter oldDelegate) => false;
}

/// "SK vs ?" göstergesi: oyuncunun baş harfleri (şeftali daire; ad yoksa kişi
/// ikonu), "VS" ve kesik çizgili "?" (henüz rakip yok). Süstür; ekran
/// okuyucudan gizli. Boyax kahramanın üstünde durur.
class SahneVsIndicator extends StatelessWidget {
  const SahneVsIndicator({super.key, this.initials});

  final String? initials;

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SahneAvatar(
            size: _size,
            initial: initials,
            icon: initials == null ? AppIcons.user : null,
            color: SahneVivid.vsAvatar,
            foreground: SahneVivid.vsAvatarTx,
          ),
          const SizedBox(width: SahneSpace.x1 + 2),
          Text(
            'VS',
            style: SahneType.eyebrow.copyWith(
              color: SahneVivid.onFill,
              letterSpacing: 14 * 0.06,
            ),
          ),
          const SizedBox(width: SahneSpace.x1 + 2),
          SizedBox.square(
            dimension: _size,
            child: CustomPaint(
              painter: _DashedCirclePainter(),
              child: Center(
                child: Text(
                  '?',
                  style: SahneType.button.copyWith(color: SahneVivid.onFill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SahneVivid.vsDash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = (size.shortestSide - 1.5) / 2;
    final center = size.center(Offset.zero);
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * 2 * math.pi / dashes,
        math.pi / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) => false;
}

/// Zêr tonlu blok ("Bu hafta" sırası): altın gradyan + ince altın kenar.
/// Sıra numarası burada büyük ve altın durur; ödül/prestij rengi yalnız bu
/// tür yüzeylerde.
class SahneGoldBlock extends StatelessWidget {
  const SahneGoldBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.goldBlockFrom, t.goldBlockTo],
        ),
        shape: SahneShape.withSide(SahneShape.m, t.goldBlockEdge, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: child,
      ),
    );
  }
}

/// Yarış merkezinin mod kartı (2026-10-22 tasarım kurulu: ChatGPT,
/// Gemini 3.1 Pro, Claude Opus; üçü de "liste satırları büyük renkli mod
/// kartlarına dönmeli" dedi, TRT Bil Bakalım / Trivia Crack kıyası).
///
/// Ana sayfadaki konu karosuyla aynı dil: rolün DOLU rengi (Boyax, Nîl ya da
/// Zêr bandı), pahlı L köşe, beyaz ikon ve kalın ad, sağ altta beyaz %12
/// büyük ikon filigranı. Zêr bandında yazı ve ikon koyudur (`onZer`).
class SahneModeTile extends StatelessWidget {
  const SahneModeTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.role = SahneRole.race,
    this.onTap,
    this.badge,
    this.loading = false,
    this.semanticLabel,
    this.deep = false,
  });

  /// Rolün koyu tonu (şimdilik yalnız Boyax): aynı roldeki kartlar alt alta
  /// gelince birbirine karışmasın (kurul 2. tur, Claude Opus + ChatGPT).
  final bool deep;

  final IconData icon;
  final String title;
  final String? subtitle;
  final SahneRole role;
  final VoidCallback? onTap;

  /// Sağ üstte küçük sayı rozeti (ör. bekleyen istek).
  final String? badge;
  final bool loading;
  final String? semanticLabel;

  static const double minHeight = 112;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final gold = role == SahneRole.gold;
    final fill = switch (role) {
      SahneRole.social => t.nilFill,
      SahneRole.learn => t.learnFill,
      SahneRole.gold => t.zerBand,
      _ => deep ? t.raceDeep : t.raceFill,
    };
    final ink = gold ? t.onZer : SahneVivid.onFill;
    // Zêr bandında alt yazı da tam koyu: %82 gece ve gündüz zayıf okunuyordu.
    // Son kurul (ChatGPT 8,8, Grok 8,5, Nemotron 7; üçünün ortak bulgusu):
    // gecede ikincil yazı ve filigran kayboluyor, kart kenarı seçilmiyordu.
    // Gece: koyu tonda alt yazı tam beyaz, filigran %18, ince açık kenar.
    final night = Theme.of(context).brightness == Brightness.dark;
    final soft = gold
        ? t.onZer
        : (night && deep ? SahneVivid.onFill : SahneVivid.onFillSoft);
    final watermark = gold
        ? t.onZer.withValues(alpha: night ? 0.18 : 0.12)
        : (night ? SahneVivid.watermarkNight : SahneVivid.watermark);
    final enabled = onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel ?? [title, ?subtitle].join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: SahneTappable(
          shape: night
              ? SahneShape.withSide(
                  SahneShape.l,
                  SahneVivid.tileEdgeNight,
                  width: 1,
                )
              : SahneShape.l,
          color: fill,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -10,
                  bottom: -14,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: -10 * math.pi / 180,
                      child: Icon(icon, size: 76, color: watermark),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(SahneSpace.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 26, color: ink),
                          const Spacer(),
                          if (loading)
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ink,
                              ),
                            )
                          else if (badge != null)
                            DecoratedBox(
                              decoration: ShapeDecoration(
                                color: gold ? t.zerChip : SahneVivid.onFill,
                                shape: const StadiumBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SahneSpace.x2,
                                  vertical: 2,
                                ),
                                child: Text(
                                  badge!,
                                  style: SahneType.captionStrong.copyWith(
                                    color: gold ? t.goldTx : fill,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: SahneSpace.x3),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SahneType.bodyStrong.copyWith(color: ink),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.caption.copyWith(color: soft),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İki sütunlu mod kartı ızgarası; dar ekranda ya da büyük yazıda tek sütun.
class SahneModeGrid extends StatelessWidget {
  const SahneModeGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = SahneSpace.x3;
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = constraints.maxWidth < 300 || scale > 1.6 ? 1 : 2;
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        // Aynı satırdaki iki kart eşit boyda (alt yazısı olan ile olmayan
        // yan yana kısa-uzun duruyordu).
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          final right = i + 1 < children.length ? children[i + 1] : null;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  const SizedBox(width: gap),
                  Expanded(child: right ?? const SizedBox.shrink()),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
