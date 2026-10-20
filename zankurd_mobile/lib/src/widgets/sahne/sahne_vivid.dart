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
