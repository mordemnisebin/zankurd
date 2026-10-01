import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_painters.dart';

/// Eski ad. 2026-09-29 doğallık (K5): avatar elmas değil pahlı kare;
/// çağıranlar kırılmasın diye ad [SahneAvatar]a yönlenir.
typedef SahneDiamondAvatar = SahneAvatar;

/// Avatar — sıra satırı, VS amblemi (maketteki `.sh-lav`, `.sh-vs-a/b`).
///
/// Boyuna uygun pahlı kare ([SahneShape.forSize]: 36 → M) içinde baş harf
/// (düğme biçemi) ya da ikon; madalya ya da seçim rengi [ring] ile içe
/// çizilir (Halka 1/2/3). Dekoratiftir: satırın kendisi adı okur.
///
/// 2026-09-29 doğallık (K5): eskiden elmastı. Elmas avatarda, ilerlemede,
/// sayaçta, yol düğümünde ve rozette aynı anda olunca tek bir anlam
/// taşımıyordu; elmas yalnız soru ilerlemesi ve ders sayacında kalır. Kare
/// iç alanı elmasınkinden geniş olduğu için harf ve ikon biraz büyüdü.
class SahneAvatar extends StatelessWidget {
  const SahneAvatar({
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
            shape: ringColor == null
                ? SahneShape.forSize(size)
                : SahneShape.withSide(
                    SahneShape.forSize(size),
                    ringColor,
                    width: ringWidth,
                  ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: size * 0.5, color: fg)
                : SizedBox.square(
                    dimension: size * 0.6,
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

enum _RowKind { standard, info, rank, me, custom, plain }

/// Liste satırı — maketteki "5 · Liste satırı" (`.sh-row`).
///
/// * [SahneListRow.icon] — standart, ≥ 64: 44'lük ikon karosu (rol tonu
///   zemin + rol metni ikon, M pah).
/// * [SahneListRow.thumb] — bilgi, ≥ 52: 36'lık küçük resim (M pah, kaşsız).
/// * [SahneListRow.plain] — ikonsuz, ≥ 56: öncül yok, metin satırın
///   kenarından başlar; sağda yalnız ok ([chevron]) YA DA değer
///   ([trailing]). Ayarlar gibi ikonun metni tekrarladığı listeler için
///   (2026-09-29 doğallık, K7: her satırın başında ikon karosu şablon izi).
/// * [SahneListRow.rank] — sıra, ≥ 56: sıra no + 36'lık avatar.
/// * [SahneListRow.me] — "Sen": Zêr tonu degrade + Halka 1 altın, L pah;
///   grubun DIŞINDA tek başına durur.
/// * [SahneListRow.leading] — serbest öncül (ör. `PlayerAvatar`); ≥ 64,
///   ayırıcı öncülün genişliğinden ([leadingWidth]) hizalanır.
///
/// Sıra ve "Sen" satırında avatarın yerine oyuncunun kendi avatarı
/// verilebilir ([avatar], 36'lık yuva). Bilgi satırında resim yoksa
/// ([image] `null`) çizimsiz kategori karosunun 36'lık küçüğü ([tone]) çizilir —
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
       tone = SahneCategoryTone.fallback,
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
    this.tone = SahneCategoryTone.fallback,
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
       tone = SahneCategoryTone.fallback,
       leadingWidget = leading,
       icon = null,
       image = null,
       role = SahneRole.neutral,
       rank = null,
       initial = null,
       avatar = null;

  /// İkonsuz satır: öncül yok, metin satırın kenarından (16) başlar.
  /// Satırın tamamı dokunulur; sağda ok ya da değer, ikisi birden değil.
  const SahneListRow.plain({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.destructive = false,
  }) : assert(
         trailing == null || !chevron,
         'İkonsuz satırın sağında ok YA DA değer durur, ikisi birden değil.',
       ),
       _kind = _RowKind.plain,
       tone = SahneCategoryTone.fallback,
       icon = null,
       image = null,
       role = SahneRole.neutral,
       rank = null,
       initial = null,
       avatar = null,
       leadingWidget = null,
       leadingWidth = 0;

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
       tone = SahneCategoryTone.fallback,
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
       tone = SahneCategoryTone.fallback,
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

  /// Bilgi satırının çizimsiz küçüğünün kategori tonu.
  final SahneCategoryTone tone;

  /// Sıra/"Sen" satırında avatarın yerine (36'lık yuva).
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
    _RowKind.plain => SahneSpace.x4,
  };

  double get _minHeight => switch (_kind) {
    _RowKind.standard || _RowKind.me || _RowKind.custom => 64,
    _RowKind.info => 52,
    _RowKind.rank || _RowKind.plain => 56,
  };

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isMe = _kind == _RowKind.me;

    // Çizimsiz kategori küçüğü: kategorinin düz tonu + ikon, 36.
    Widget noArt() => SizedBox.square(
      dimension: 36,
      child: CustomPaint(
        painter: SahneNoArtPainter(tone: tone),
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
      case _RowKind.plain:
        leading = null;
      case _RowKind.info:
        final img = image;
        leading = ClipPath(
          clipper: const ShapeBorderClipper(shape: SahneShape.m),
          child: img == null
              ? noArt()
              : DecoratedBox(
                  decoration: BoxDecoration(color: tone.ground),
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
                ? SahneAvatar(
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
        padding: EdgeInsetsDirectional.fromSTEB(
          // İkonsuz satırda metin kartın iç kenarından (16) başlar.
          leading == null ? SahneSpace.x4 : SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x4,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              ExcludeSemantics(child: leading),
              const SizedBox(width: SahneSpace.x3),
            ],
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

  /// Ayırıcının sağ (son) iç boşluğu; kartın kenarına değmez.
  static const double dividerEndInset = SahneSpace.x4;

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
                  // Ayırıcı iki yandan içeridedir: başta ikon/avatar hizası,
                  // sonda [dividerEndInset]. Eskiden sağ kenara kadar
                  // uzanıyor, kartın pahlı kenarının dışına taşıyordu
                  // (2026-10-01 tasarım denetimi: ayarlar, paywall, düello
                  // kutusu, alt konu listesi).
                  padding: EdgeInsetsDirectional.only(
                    start: switch (children[i]) {
                      final SahneListRow row => row.dividerIndent,
                      _ => dividerIndent,
                    },
                    end: dividerEndInset,
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
