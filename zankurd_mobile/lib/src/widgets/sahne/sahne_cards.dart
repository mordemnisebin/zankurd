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
import 'sahne_topic_marks.dart';

enum _StageKind { plain, lesson, duel, mini }

/// Sahne kartı — kahraman içerik (maketteki "2 · Sahne kartı",
/// `.sh-stage`).
///
/// Gece degradesi (`SahneStageColors.top → bottom`) + sol üstten rol
/// radyali; yarış rolünde Boyax sahne degradesi (race1 → race3). L pah.
/// Üst kenardaki rol renkli kilim göz şeridi (8 px, %55) İSTEĞE BAĞLIDIR
/// ([kilim], varsayılan kapalı). Gündüz
/// temasında da GECE çizilir: içerik `AppTheme.stage` ile sarılır, altındaki
/// her bileşen gece belirteçlerini alır.
///
/// * [SahneStageCard.lesson] — etiket + manşet + açıklama + ders elması +
///   tam genişlik birincil düğme.
/// * [SahneStageCard.duel] — yarış degradesi; solda metin, sağda VS amblemi
///   yuvası ([emblem], ör. [SahneVsEmblem]); altında birincil düğme.
/// * [SahneStageCard.mini] — etiket + manşet + açıklama, 4 aralık.
/// * Varsayılan kurucu — yalnız zemin (+ isteğe bağlı şerit); içerik
///   serbest.
///
/// 2026-09-29 doğallık (K4): kilim şeridi her sahne kartında olunca bir
/// kimlik değil şablon izi oluyordu. Şerit yalnız anlamlı yerlerde açılır
/// (onboarding, zafer sonucu, giriş): `kilim: true`.
///
/// Üst etiket ([eyebrow]) açıklama kalınında ve cümle düzenindedir (K8);
/// büyük harf yalnız soru ekranının künyesinde kalır.
class SahneStageCard extends StatelessWidget {
  const SahneStageCard({
    super.key,
    required Widget this.child,
    this.role = SahneRole.learn,
    this.kilim = false,
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
       metaIcon = null,
       actionKey = null,
       loading = false,
       semanticLabel = null;

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
    this.actionKey,
    this.loading = false,
    this.semanticLabel,
    this.kilim = false,
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
    this.actionKey,
    this.loading = false,
    this.semanticLabel,
    this.kilim = false,
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
    this.kilim = false,
  }) : _kind = _StageKind.mini,
       child = null,
       tag = null,
       done = 0,
       total = 0,
       actionLabel = null,
       onAction = null,
       emblem = null,
       metaIcon = null,
       actionKey = null,
       loading = false,
       semanticLabel = null,
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

  /// Üst kenarda rol renkli kilim şeridi; varsayılan kapalı (K4).
  final bool kilim;

  /// Üst etiket: açıklama kalını, cümle düzeni, rol metni renginde.
  final String? eyebrow;

  /// Üst etiket yerine rozet (ör. `SahneBadge`: "Sana önerilen").
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

  /// Birincil düğmenin anahtarı (içteki `FilledButton`).
  final Key? actionKey;

  /// Birincil düğme yükleniyor (görünüş korunur, dokunuş yok sayılır).
  final bool loading;

  /// Verilirse kart TEK bir ekran okuyucu düğümüdür: bu söz + düğmenin
  /// eylemi (ör. "Hızlı düello. Rakip bul"); iç metinler ayrı okunmaz.
  final String? semanticLabel;

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
            eyebrow!,
            style: SahneType.captionStrong.copyWith(color: eyebrowColor),
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
      buttonKey: actionKey,
      label: actionLabel!,
      onPressed: onAction,
      loading: loading,
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
          // Metne en az altı manşet harfi kalmıyorsa amblem metnin altına
          // iner (ders kartıyla aynı kural).
          LayoutBuilder(
            builder: (context, c) {
              final room = c.maxWidth - SahneVsEmblem.width - SahneSpace.x3;
              final wide =
                  emblem == null ||
                  room >= MediaQuery.textScalerOf(context).scale(22) * 6;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: texts(gap: SahneSpace.x1)),
                    if (emblem != null) ...[
                      const SizedBox(width: SahneSpace.x3),
                      emblem!,
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  texts(gap: SahneSpace.x1),
                  const SizedBox(height: SahneSpace.x3),
                  emblem!,
                ],
              );
            },
          ),
          const SizedBox(height: SahneSpace.x4),
          action(),
        ],
      ),
    };

    final card = ClipPath(
      clipper: const ShapeBorderClipper(shape: SahneShape.l),
      child: CustomPaint(
        painter: SahneStagePainter(
          race: race,
          glow: race ? null : t.roleGlow(role),
        ),
        child: kilim
            ? Stack(
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
              )
            : Padding(padding: padding, child: content),
      ),
    );
    final label = semanticLabel;
    if (label == null) return card;
    final enabled = onAction != null && !loading;
    return Semantics(
      container: true,
      button: onAction != null,
      enabled: enabled,
      label: actionLabel == null ? label : '$label. $actionLabel',
      onTap: enabled ? onAction : null,
      excludeSemantics: true,
      child: card,
    );
  }
}

/// VS amblemi — düello kartının sağ yuvası (maketteki `.sh-vs`).
///
/// Bileşik, yeni ilkel değil: iki 40'lık avatar (pahlı kare, K5) YAN YANA,
/// aralarında Etiket biçeminde "VS". Oyuncu solda (birincil metin dolgu +
/// Halka 3 altın + kişi ikonu), rakip sağda (yarış koyusu dolgu + Halka 2
/// yumuşak lal + "?" ya da baş harf). 104 × 40; dekoratif.
///
/// 2026-09-29 doğallık: avatarlar elmasken çapraz dizilişte "VS" iki
/// elmasın boş köşelerine otururdu; avatarlar pahlı kare olunca o köşeler
/// doldu ve "VS" iki karonun arasına sıkışıp üstlerine biniyordu. Yan yana
/// dizilişte harfler kendi 24'lük yuvasındadır; büyük yazı ölçeğinde
/// küçülür, taşmaz.
class SahneVsEmblem extends StatelessWidget {
  const SahneVsEmblem({super.key, this.opponentInitial = '?'});

  final String opponentInitial;

  /// Amblemin genişliği (düello kartı yerleşimi bununla ölçer).
  static const double width = 104;
  static const double _avatar = 40;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: _avatar,
        child: Row(
          children: [
            SahneAvatar(
              size: _avatar,
              icon: AppIcons.user,
              color: t.tx,
              foreground: SahneStageColors.race2,
              ring: t.gold,
              ringWidth: SahneRing.r3,
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'VS',
                    maxLines: 1,
                    style: SahneType.eyebrow.copyWith(
                      color: t.tx,
                      letterSpacing: 14 * 0.06,
                    ),
                  ),
                ),
              ),
            ),
            SahneAvatar(
              size: _avatar,
              initial: opponentInitial,
              color: SahneStageColors.race3,
              foreground: SahneStageColors.raceSoft,
              ring: SahneStageColors.raceSoft,
              ringWidth: SahneRing.r2,
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
      child: SahneOnSurface(
        child: Padding(padding: padding, child: child),
      ),
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
/// * Çizimsiz — [image] `null` ya da görsel yüklenemezse: kategorinin
///   düz tonu ([tone], [SahneNoArtPainter]) + 48'lik çizgi ikon ([icon]).
///   Kategori tonu `CategoryVisuals.tone(kategori)` ile verilir. [mark]
///   verilirse ikon yerine konunun K3 silüeti çizilir
///   ([SahneCategoryGlyphPainter]; pah yüzeyi olmadan, düz zemin).
///
/// Altında ad (Gövde 700) ve öteki dildeki ad (Açıklama, ikincil metin),
/// en altta isteğe bağlı meta yuvası ([meta]: ilerleme çubuğu, "245 soru").
/// Dokunma alanı karonun TAMAMIDIR — ad ve meta da dahil (eskiden yalnız
/// kare dokunuluyordu, ada dokunan oyuncu boşa basıyordu). Dalga pah
/// şekline uyar; ekran okuyucu "ad, öteki ad, meta" ve ustalık sözünü
/// okur ([metaLabel]).
class SahneJewelTile extends StatelessWidget {
  const SahneJewelTile({
    super.key,
    required this.name,
    this.otherName,
    this.semanticName,
    this.image,
    this.icon = AppIcons.clapperboard,
    this.mastered = false,
    this.masteredLabel,
    this.onTap,
    this.size = 128,
    this.width,
    this.meta,
    this.metaLabel,
    this.tone = SahneCategoryTone.fallback,
    this.mark,
  });

  /// Karonun altındaki yazı sütununun genişliği; verilmezse [size].
  /// 2026-09-30 simülatör: büyük yazıda ızgara sütun sayısını düşürür ve
  /// sütun karodan geniş olabilir; ad o genişlikte dizilir, kare ise
  /// [size]'da kalır.
  final double? width;

  /// Çizimsiz çeşidin zemini (kategori tonu).
  final SahneCategoryTone tone;

  /// Çizimsiz çeşidin silüeti (K3, 2026-09-30 kimlik). `null` ise [icon]
  /// çizilir: silüeti olmayan konu eski ikon + ton hâlinde kalır.
  final SahneTopicMark? mark;

  /// Adların altındaki yuva (ör. ilerleme çubuğu ya da soru sayısı).
  final Widget? meta;

  /// Meta yuvasının ekran okuyucu sözü (ör. "%40").
  final String? metaLabel;

  final String name;
  final String? otherName;

  /// Ekran okuyucunun okuduğu ad (ör. kısa karo adı "Bilim" iken tam ad
  /// "Bilim ve Düşünce, Zanist û Raman"). `null` ise [name] ve [otherName].
  final String? semanticName;
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

    Widget noArt() => mark != null
        ? CustomPaint(
            painter: SahneCategoryGlyphPainter(mark: mark!, tone: tone),
          )
        : CustomPaint(
            painter: SahneNoArtPainter(tone: tone),
            child: Center(
              child: Icon(
                icon,
                size: 48 * size / 128,
                color: SahneTokens.night.tx,
              ),
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
              child: ColoredBox(color: tone.ground, child: art),
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
      semanticName ?? name,
      if (semanticName == null) ?otherName,
      ?metaLabel,
      if (mastered && masteredLabel != null) masteredLabel!,
    ].join(', ');

    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        // Ad ve meta da dokunma alanında: karonun altındaki metne basmak
        // da konuyu açar.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width ?? size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              jewel,
              const SizedBox(height: SahneSpace.x3),
              // 2026-09-30 izgara: yazı bloğu SABİT yüksekliktedir. Ad ve öteki
              // ad birer satırdır (sarmaz, sığmazsa "…"); öteki ad yoksa satırı
              // bölünmez boşlukla AYRILIR (ızgara karoları arası sayı ve çubuk
              // aynı hizada kalır). Uzun adın sarıp karoyu uzatması, ızgarada
              // satır boylarını eşitsiz bırakıyordu.
              Text(
                name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: SahneType.bodyStrong.copyWith(color: t.tx),
              ),
              Text(
                otherName ?? '\u00A0',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              ?meta,
            ],
          ),
        ),
      ),
    );
  }
}

/// Ustalık rozeti: 28'lik Zêr pahlı kare (S), zemin renginde 2 px kontur,
/// içinde 12'lik koyu yıldız. 2026-09-29 doğallık (K5): elmas yalnız soru
/// ilerlemesi ve ders sayacında kalır.
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
          shape: SahneShape.withSide(
            SahneShape.s,
            tokens.bg,
            width: SahneRing.r2,
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
