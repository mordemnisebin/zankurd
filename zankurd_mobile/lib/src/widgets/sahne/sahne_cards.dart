import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/sahne.dart';
import 'sahne_buttons.dart';
import 'sahne_foundation.dart';
import 'sahne_glyphs.dart';
import 'sahne_list_row.dart';
import 'sahne_painters.dart';
import 'sahne_progress.dart';

enum _StageKind { plain, lesson, duel, mini }

/// Sahne kartı — kahraman içerik (maketteki "2 · Sahne kartı",
/// `.sh-stage`).
///
/// Gece degradesi (`SahneStageColors.top → bottom`) + sol üstten rol
/// radyali; yarış rolünde Boyax sahne degradesi (race1 → race3). Üst
/// kenarda rol renkli kilim göz şeridi (8 px, %55). L pah. Gündüz
/// temasında da GECE çizilir: içerik `AppTheme.stage` ile sarılır, altındaki
/// her bileşen gece belirteçlerini alır.
///
/// * [SahneStageCard.lesson] — etiket + manşet + açıklama + ders elması +
///   tam genişlik birincil düğme.
/// * [SahneStageCard.duel] — yarış degradesi; solda metin, sağda VS amblemi
///   yuvası ([emblem], ör. [SahneVsEmblem]); altında birincil düğme.
/// * [SahneStageCard.mini] — etiket + manşet + açıklama, 4 aralık.
/// * Varsayılan kurucu — yalnız zemin + şerit; içerik serbest.
class SahneStageCard extends StatelessWidget {
  const SahneStageCard({
    super.key,
    required Widget this.child,
    this.role = SahneRole.learn,
    this.padding = const EdgeInsets.fromLTRB(
      SahneSpace.x4,
      SahneSpace.x5,
      SahneSpace.x4,
      SahneSpace.x4,
    ),
  }) : _kind = _StageKind.plain,
       eyebrow = null,
       tag = null,
       title = null,
       meta = null,
       done = 0,
       total = 0,
       actionLabel = null,
       onAction = null,
       emblem = null,
       metaIcon = null;

  const SahneStageCard.lesson({
    super.key,
    required String this.title,
    required String this.actionLabel,
    required this.onAction,
    required this.done,
    required this.total,
    this.eyebrow,
    this.tag,
    this.meta,
  }) : _kind = _StageKind.lesson,
       role = SahneRole.learn,
       child = null,
       emblem = null,
       metaIcon = null,
       padding = const EdgeInsets.fromLTRB(
         SahneSpace.x4,
         SahneSpace.x5,
         SahneSpace.x4,
         SahneSpace.x4,
       );

  const SahneStageCard.duel({
    super.key,
    required String this.title,
    required String this.actionLabel,
    required this.onAction,
    this.eyebrow,
    this.meta,
    this.metaIcon = AppIcons.clock,
    this.emblem,
  }) : _kind = _StageKind.duel,
       role = SahneRole.race,
       child = null,
       tag = null,
       done = 0,
       total = 0,
       padding = const EdgeInsets.fromLTRB(
         SahneSpace.x4,
         SahneSpace.x5,
         SahneSpace.x4,
         SahneSpace.x4,
       );

  const SahneStageCard.mini({
    super.key,
    required String this.title,
    this.eyebrow,
    this.meta,
    this.role = SahneRole.learn,
  }) : _kind = _StageKind.mini,
       child = null,
       tag = null,
       done = 0,
       total = 0,
       actionLabel = null,
       onAction = null,
       emblem = null,
       metaIcon = null,
       padding = const EdgeInsets.fromLTRB(
         SahneSpace.x4,
         SahneSpace.x5,
         SahneSpace.x4,
         SahneSpace.x4,
       );

  final _StageKind _kind;
  final SahneRole role;
  final Widget? child;
  final EdgeInsets padding;

  /// Üst etiket (büyük harfe yerele duyarlı çevrilir), rol metni renginde.
  final String? eyebrow;

  /// Üst etiket yerine rozet (ör. `SahneBadge`: "SANA ÖNERİLEN").
  final Widget? tag;
  final String? title;
  final String? meta;
  final IconData? metaIcon;

  /// Ders elması: "done/total".
  final int done;
  final int total;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Düello: VS amblemi yuvası.
  final Widget? emblem;

  @override
  Widget build(BuildContext context) {
    return SahneStage(
      stage: AppTheme.stage,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final t = SahneTokens.of(context);
    final race = role == SahneRole.race;
    final metaColor = race ? SahneStageColors.raceSoft : t.tx2;
    final eyebrowColor = race ? SahneStageColors.raceSoft : t.roleText(role);

    Widget texts({required double gap}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tag != null) ...[tag!, SizedBox(height: gap)],
        if (tag == null && eyebrow != null) ...[
          Text(
            sahneUpper(context, eyebrow!),
            style: SahneType.eyebrow.copyWith(color: eyebrowColor),
          ),
          SizedBox(height: gap),
        ],
        Semantics(
          header: true,
          child: Text(title!, style: SahneType.headline.copyWith(color: t.tx)),
        ),
        if (meta != null) ...[
          SizedBox(height: gap),
          Row(
            children: [
              if (metaIcon != null) ...[
                Icon(metaIcon, size: 16, color: metaColor),
                const SizedBox(width: SahneSpace.x1),
              ],
              Flexible(
                child: Text(
                  meta!,
                  style: SahneType.caption.copyWith(color: metaColor),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    Widget action() => SahneButton.primary(
      label: actionLabel!,
      onPressed: onAction,
      expand: true,
    );

    final Widget content = switch (_kind) {
      _StageKind.plain => child!,
      _StageKind.mini => texts(gap: SahneSpace.x1),
      _StageKind.lesson => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metne en az altı manşet harfi kalmıyorsa (büyük yazı, dar
          // ekran) ders elması metnin altına iner; başlık harf harf
          // bölünmez.
          LayoutBuilder(
            builder: (context, c) {
              final room = c.maxWidth - 80 - SahneSpace.x4;
              final wide =
                  room >= MediaQuery.textScalerOf(context).scale(22) * 6;
              final diamond = SahneLessonDiamond(done: done, total: total);
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: texts(gap: SahneSpace.x1)),
                    const SizedBox(width: SahneSpace.x4),
                    diamond,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  texts(gap: SahneSpace.x1),
                  const SizedBox(height: SahneSpace.x3),
                  diamond,
                ],
              );
            },
          ),
          const SizedBox(height: SahneSpace.x4),
          action(),
        ],
      ),
      _StageKind.duel => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: texts(gap: SahneSpace.x1)),
              if (emblem != null) ...[
                const SizedBox(width: SahneSpace.x3),
                emblem!,
              ],
            ],
          ),
          const SizedBox(height: SahneSpace.x4),
          action(),
        ],
      ),
    };

    return ClipPath(
      clipper: const ShapeBorderClipper(shape: SahneShape.l),
      child: CustomPaint(
        painter: SahneStagePainter(
          race: race,
          glow: race ? null : t.roleGlow(role),
        ),
        child: Stack(
          children: [
            Padding(padding: padding, child: content),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: SahneKilimStrip(
                color: t.roleText(role).withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// VS amblemi — düello kartının sağ yuvası (maketteki `.sh-vs`).
///
/// Bileşik, yeni ilkel değil: iki 48'lik elmas avatar. Oyuncu sol üstte
/// (birincil metin dolgu + Halka 3 altın + kişi ikonu), rakip sağ altta
/// (yarış koyusu dolgu + Halka 2 yumuşak lal + "?" ya da baş harf);
/// ortada Etiket biçeminde "VS". 104 × 80; dekoratif.
class SahneVsEmblem extends StatelessWidget {
  const SahneVsEmblem({super.key, this.opponentInitial = '?'});

  final String opponentInitial;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: 104,
        height: 80,
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              child: SahneDiamondAvatar(
                size: 48,
                icon: AppIcons.user,
                color: t.tx,
                foreground: SahneStageColors.race2,
                ring: t.gold,
                ringWidth: SahneRing.r3,
              ),
            ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: SahneDiamondAvatar(
                size: 48,
                initial: opponentInitial,
                color: SahneStageColors.race3,
                foreground: SahneStageColors.raceSoft,
                ring: SahneStageColors.raceSoft,
                ringWidth: SahneRing.r2,
              ),
            ),
            Center(
              child: Text(
                'VS',
                style: SahneType.eyebrow.copyWith(
                  color: t.tx,
                  letterSpacing: 14 * 0.06,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yüzey kartı — liste ve bilgi yüzeyi (maketteki `.sh-card`).
///
/// Perde (`s1`), L pah; gecede kenarsız (katman tonla ayrılır), gündüzde
/// 1 px kenar (`edge`). Bulanık gölge yok. Dokunulabilirse dalga pahtan
/// taşmaz. Ödül kartı, istatistik karosu ve kilitli ders satırı bunun
/// üstüne kurulur.
class SahneSurfaceCard extends StatelessWidget {
  const SahneSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SahneSpace.x4),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final card = SahneTappable(
      shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      color: t.s1,
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
    if (semanticLabel == null && onTap == null) return card;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: card,
    );
  }
}

/// Mücevher karo — kategori karosu (maketteki "4 · Mücevher karo",
/// `.sh-cat`).
///
/// 128 kare, L pah, GÖLGESİZ (raf kaydırmasında bulanıklık yok). Üç çeşit:
///
/// * Çizimli — [image] verilir; kaş nötr (`rim`, Halka 1).
/// * Ustalık — [mastered]: kaş altın + sağ üstte elmas yıldız rozeti.
/// * Çizimsiz — [image] `null` (Sinema ve çizimi olmayan her kategori) ya
///   da görsel yüklenemezse: kobalt radyal + kilim şerit çerçeve + kemer +
///   48'lik Lucide ikonu ([icon]).
///
/// Altında ad (Gövde 700) ve öteki dildeki ad (Açıklama, ikincil metin).
/// Dokunulabilir: dalga pah şekline uyar; ekran okuyucu "ad, öteki ad" ve
/// ustalık sözünü okur.
class SahneJewelTile extends StatelessWidget {
  const SahneJewelTile({
    super.key,
    required this.name,
    this.otherName,
    this.image,
    this.icon = AppIcons.clapperboard,
    this.mastered = false,
    this.masteredLabel,
    this.onTap,
    this.size = 128,
  });

  final String name;
  final String? otherName;
  final ImageProvider? image;

  /// Çizimsiz çeşidin ikonu.
  final IconData icon;
  final bool mastered;

  /// Ustalık sözü (ör. "Ustalık"); ekran okuyucuya eklenir.
  final String? masteredLabel;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final rim = SahneShape.withSide(
      SahneShape.l,
      mastered ? t.gold : t.rim,
      width: SahneRing.r1,
    );

    Widget noArt() => CustomPaint(
      painter: SahneNoArtPainter(gold: t.gold, dot: t.race),
      child: Align(
        // Maket: ikon merkezin 4 px altında (kemerin ışık dairesinde).
        alignment: const Alignment(0, 8 / 128),
        child: Icon(icon, size: 48 * size / 128, color: SahneTokens.night.tx),
      ),
    );

    final art = image == null
        ? noArt()
        : Image(
            image: image!,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => noArt(),
          );

    final jewel = SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: SahneShape.l),
              child: ColoredBox(color: SahneStageColors.art2, child: art),
            ),
          ),
          // Kaş: içe çizilen Halka 1 (nötr ya da altın).
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: ShapeDecoration(shape: rim)),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(customBorder: SahneShape.l, onTap: onTap),
            ),
          ),
          if (mastered)
            PositionedDirectional(
              end: -4,
              top: -4,
              child: _MasterBadge(tokens: t),
            ),
        ],
      ),
    );

    final label = [
      name,
      ?otherName,
      if (mastered && masteredLabel != null) masteredLabel!,
    ].join(', ');

    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            jewel,
            const SizedBox(height: SahneSpace.x3),
            Text(name, style: SahneType.bodyStrong.copyWith(color: t.tx)),
            if (otherName != null)
              Text(otherName!, style: SahneType.caption.copyWith(color: t.tx2)),
          ],
        ),
      ),
    );
  }
}

/// Ustalık rozeti: 28'lik Zêr elmas, zemin renginde 2 px kontur, içinde
/// 12'lik koyu yıldız.
class _MasterBadge extends StatelessWidget {
  const _MasterBadge({required this.tokens});

  final SahneTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tokens.gold,
          shape: SahneShape.diamond(
            28,
            side: BorderSide(color: tokens.bg, width: SahneRing.r2),
          ),
        ),
        child: Center(
          child: SahneGlyph(
            SahneGlyphKind.star,
            size: 12,
            color: tokens.onGold,
            edgeColor: tokens.onGold,
          ),
        ),
      ),
    );
  }
}
