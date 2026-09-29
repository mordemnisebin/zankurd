import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_painters.dart';

/// Elmas avatar — sıra satırı, podyum, VS amblemi (maketteki `.sh-lav`,
/// `.sh-pav`, `.sh-vs-a/b`).
///
/// Elmas maske içinde baş harf (düğme biçemi) ya da ikon; madalya ya da
/// seçim rengi [ring] ile içe çizilir (Halka 1/2/3). Dekoratiftir: satırın
/// kendisi adı okur.
class SahneDiamondAvatar extends StatelessWidget {
  const SahneDiamondAvatar({
    super.key,
    this.initial,
    this.icon,
    this.size = 36,
    this.color,
    this.foreground,
    this.ring,
    this.ringWidth = SahneRing.r1,
    this.textStyle,
  });

  final String? initial;
  final IconData? icon;
  final double size;

  /// Dolgu; varsayılan Ray (`s3`).
  final Color? color;

  /// Harf/ikon rengi; varsayılan birincil metin.
  final Color? foreground;
  final Color? ring;
  final double ringWidth;

  /// Varsayılan: düğme biçemi (Bricolage 800, 16).
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fg = foreground ?? t.tx;
    final ringColor = ring;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: color ?? t.s3,
            shape: SahneShape.diamond(
              size,
              side: ringColor == null
                  ? null
                  : BorderSide(
                      color: ringColor,
                      width: ringWidth,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: size * 0.44, color: fg)
                : SizedBox.square(
                    dimension: size * 0.5,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        initial ?? '',
                        maxLines: 1,
                        style: (textStyle ?? SahneType.button).copyWith(
                          color: fg,
                          height: 1,
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

/// Satırın sağındaki değer (maketteki `.sh-trail`).
///
/// * Varsayılan — değer: Gövde 700, tablo rakamı ("1/1", "5980"); rengi
///   satırdan (birincil metin; Sen satırında koyu altın).
/// * [SahneRowValue.meta] — ek bilgi: kalın açıklama, üçüncül metin
///   ("4 dk").
class SahneRowValue extends StatelessWidget {
  const SahneRowValue(this.text, {super.key}) : meta = false;

  const SahneRowValue.meta(this.text, {super.key}) : meta = true;

  final String text;
  final bool meta;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Text(
      text,
      style: meta
          ? SahneType.captionStrong.copyWith(color: t.tx3)
          // Renk satırdan gelir: Sen satırında koyu altın, ötekilerde
          // birincil metin.
          : SahneType.bodyStrong.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
    );
  }
}

enum _RowKind { standard, info, rank, me, custom }

/// Liste satırı — maketteki "5 · Liste satırı" (`.sh-row`).
///
/// * [SahneListRow.icon] — standart, ≥ 64: 44'lük ikon karosu (rol tonu
///   zemin + rol metni ikon, M pah).
/// * [SahneListRow.thumb] — bilgi, ≥ 52: 36'lık küçük resim (M pah, kaşsız).
/// * [SahneListRow.rank] — sıra, ≥ 56: sıra no + 36'lık elmas avatar.
/// * [SahneListRow.me] — "Sen": Zêr tonu degrade + Halka 1 altın, L pah;
///   grubun DIŞINDA tek başına durur.
/// * [SahneListRow.leading] — serbest öncül (ör. `PlayerAvatar`); ≥ 64,
///   ayırıcı öncülün genişliğinden ([leadingWidth]) hizalanır.
///
/// Sıra ve "Sen" satırında elmas avatarın yerine oyuncunun kendi avatarı
/// verilebilir ([avatar], 36'lık yuva). Bilgi satırında resim yoksa
/// ([image] `null`) çizimsiz kategori karosunun 36'lık küçüğü çizilir —
/// satırlar aynı hizada kalır. [destructive] (ör. "Hesabı sil"): başlık ve
/// ikon Şaş metni, ikon karosu Şaş tonu; satır yine dolu kırmızı değildir.
///
/// Başlık Gövde 700, alt satır Açıklama (ikincil metin); sağda [trailing]
/// (rozet, değer) ve isteğe bağlı chevron. Yükseklik en az değerdir, sabit
/// değil: Kurmancî dizeler (%30 daha uzun) ve büyük yazı ölçeği satırı
/// uzatır, metin sarar. [enabled] `false`: "yakında" satırı — başlık
/// ikincil, ikon üçüncül metin rengi. Satırlar [SahneListGroup] içinde
/// ikon hizasından başlayan ayırıcıyla ayrılır ([dividerIndent]).
class SahneListRow extends StatelessWidget {
  const SahneListRow.icon({
    super.key,
    required IconData this.icon,
    required this.title,
    this.subtitle,
    this.role = SahneRole.neutral,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.destructive = false,
  }) : _kind = _RowKind.standard,
       image = null,
       rank = null,
       initial = null,
       avatar = null,
       leadingWidget = null,
       leadingWidth = 44;

  /// Bilgi satırı; [image] `null` ise [icon]lu çizimsiz kategori küçüğü.
  const SahneListRow.thumb({
    super.key,
    required this.image,
    required this.title,
    this.icon = AppIcons.clapperboard,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.semanticLabel,
  }) : _kind = _RowKind.info,
       role = SahneRole.neutral,
       enabled = true,
       rank = null,
       initial = null,
       avatar = null,
       destructive = false,
       leadingWidget = null,
       leadingWidth = 36;

  /// Serbest öncüllü satır (ör. `PlayerAvatar`): [leadingWidth] ayırıcı
  /// hizası içindir (öncülün genişliği).
  const SahneListRow.leading({
    super.key,
    required Widget leading,
    required this.title,
    this.leadingWidth = 44,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.destructive = false,
  }) : _kind = _RowKind.custom,
       leadingWidget = leading,
       icon = null,
       image = null,
       role = SahneRole.neutral,
       rank = null,
       initial = null,
       avatar = null;

  const SahneListRow.rank({
    super.key,
    required int this.rank,
    required this.title,
    this.initial,
    this.icon,
    this.avatar,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticLabel,
  }) : _kind = _RowKind.rank,
       image = null,
       role = SahneRole.gold,
       chevron = false,
       enabled = true,
       destructive = false,
       leadingWidget = null,
       leadingWidth = 36;

  const SahneListRow.me({
    super.key,
    required int this.rank,
    required this.title,
    this.subtitle,
    this.icon = AppIcons.user,
    this.avatar,
    this.trailing,
    this.onTap,
    this.semanticLabel,
  }) : _kind = _RowKind.me,
       image = null,
       initial = null,
       role = SahneRole.gold,
       chevron = false,
       enabled = true,
       destructive = false,
       leadingWidget = null,
       leadingWidth = 36;

  final _RowKind _kind;
  final IconData? icon;
  final ImageProvider? image;
  final int? rank;
  final String? initial;
  final String title;
  final String? subtitle;
  final SahneRole role;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final bool enabled;

  /// Varsayılan: başlık + alt satır.
  final String? semanticLabel;

  /// Yıkıcı eylem satırı (Şaş metni).
  final bool destructive;

  /// Sıra/"Sen" satırında elmas avatarın yerine (36'lık yuva).
  final Widget? avatar;

  /// [SahneListRow.leading] öncülü.
  final Widget? leadingWidget;

  /// Öncülün genişliği (ayırıcı hizası).
  final double leadingWidth;

  /// Grup ayırıcısının sol boşluğu: standart ve bilgi satırında metnin,
  /// sıra satırında avatarın hizası (12 + öncül + 12).
  double get dividerIndent => switch (_kind) {
    _RowKind.standard => SahneSpace.x3 + 44 + SahneSpace.x3,
    _RowKind.info => SahneSpace.x3 + 36 + SahneSpace.x3,
    _RowKind.rank || _RowKind.me => SahneSpace.x3 + 24 + SahneSpace.x3,
    _RowKind.custom => SahneSpace.x3 + leadingWidth + SahneSpace.x3,
  };

  double get _minHeight => switch (_kind) {
    _RowKind.standard || _RowKind.me || _RowKind.custom => 64,
    _RowKind.info => 52,
    _RowKind.rank => 56,
  };

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isMe = _kind == _RowKind.me;

    // Çizimsiz kategori küçüğü: karonun kobalt radyali + ikon, 36.
    Widget noArt() => SizedBox.square(
      dimension: 36,
      child: CustomPaint(
        painter: SahneNoArtPainter(gold: t.gold, dot: t.race),
        child: Center(
          child: Icon(
            icon ?? AppIcons.clapperboard,
            size: 18,
            color: SahneTokens.night.tx,
          ),
        ),
      ),
    );

    Widget? leading;
    switch (_kind) {
      case _RowKind.standard:
        leading = DecoratedBox(
          decoration: ShapeDecoration(
            color: destructive ? t.errTint : t.roleTint(role),
            shape: SahneShape.m,
          ),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              icon,
              size: 24,
              color: !enabled
                  ? t.tx3
                  : destructive
                  ? t.errTx
                  : t.roleText(role),
            ),
          ),
        );
      case _RowKind.custom:
        leading = leadingWidget;
      case _RowKind.info:
        final img = image;
        leading = ClipPath(
          clipper: const ShapeBorderClipper(shape: SahneShape.m),
          child: img == null
              ? noArt()
              : DecoratedBox(
                  decoration: const BoxDecoration(color: SahneStageColors.art2),
                  child: Image(
                    image: img,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => noArt(),
                  ),
                ),
        );
      case _RowKind.rank:
      case _RowKind.me:
        leading = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$rank',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: SahneType.bodyStrong.copyWith(
                    color: isMe ? t.goldTx : t.tx2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            avatar == null
                ? SahneDiamondAvatar(
                    initial: initial,
                    icon: isMe ? icon : (initial == null ? icon : null),
                    color: isMe ? t.gold : t.s3,
                    foreground: isMe ? t.onGold : t.tx,
                  )
                : SizedBox.square(dimension: 36, child: Center(child: avatar)),
          ],
        );
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: SahneType.bodyStrong.copyWith(
            color: !enabled
                ? t.tx2
                : destructive
                ? t.errTx
                : t.tx,
          ),
        ),
        if (subtitle != null)
          Text(subtitle!, style: SahneType.caption.copyWith(color: t.tx2)),
      ],
    );

    // Büyük yazı ölçeğinde (≥ 1.5) sağdaki rozet/değer metnin altına
    // iner: başlık dar bir sütunda harf harf bölünmesin.
    final stacked = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final Widget? trail = trailing == null
        ? null
        : DefaultTextStyle.merge(
            style: SahneType.bodyStrong.copyWith(
              color: isMe ? t.goldTx : t.tx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: trailing!,
          );

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: _minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x4,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            if (leading != null) ExcludeSemantics(child: leading),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: stacked && trail != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(child: text),
                        const SizedBox(height: SahneSpace.x1),
                        trail,
                      ],
                    )
                  : ExcludeSemantics(child: text),
            ),
            if (!stacked && trail != null) ...[
              const SizedBox(width: SahneSpace.x2),
              trail,
            ],
            if (chevron) ...[
              const SizedBox(width: SahneSpace.x1),
              ExcludeSemantics(
                child: Icon(AppIcons.chevronRight, size: 20, color: t.tx3),
              ),
            ],
          ],
        ),
      ),
    );

    final label =
        semanticLabel ?? [title, if (subtitle != null) subtitle].join(', ');

    Widget body;
    if (isMe) {
      final shape = SahneShape.withSide(SahneShape.l, t.gold);
      body = Material(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        color: t.s2,
        child: Ink(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              colors: [t.goldTint, t.s2],
              stops: const [0, 0.7],
            ),
          ),
          child: onTap == null
              ? row
              : InkWell(customBorder: shape, onTap: onTap, child: row),
        ),
      );
    } else if (onTap != null) {
      body = InkWell(onTap: onTap, child: row);
    } else {
      body = row;
    }

    // Öncül ve metin satırın etiketinde okunur; sağdaki rozet/değer kendi
    // sözüyle aynı düğüme eklenir (ör. "Günün Etkinliği, …, BUGÜN").
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: enabled,
      label: label,
      child: body,
    );
  }
}

/// Liste grubu — satırları tek yüzeyde toplar (maketteki `.sh-group`).
///
/// Yüzey kartıyla aynı: Perde (`s1`), L pah; gecede kenarsız (katman tonla
/// ayrılır), gündüzde 1 px kenar. Satırlar arasına ikon hizasından
/// başlayan 1 px ayırıcı (`line`) konur: [SahneListRow]'un
/// `dividerIndent`i, başka bir çocukta [dividerIndent]. Dalga pahtan
/// taşmaz.
class SahneListGroup extends StatelessWidget {
  const SahneListGroup({
    super.key,
    required this.children,
    this.dividerIndent = SahneSpace.x4,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Material(
      color: t.s1,
      shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      clipBehavior: Clip.antiAlias,
      child: SahneOnSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: switch (children[i]) {
                      final SahneListRow row => row.dividerIndent,
                      _ => dividerIndent,
                    },
                  ),
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: 1,
                      child: ColoredBox(color: t.line),
                    ),
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
