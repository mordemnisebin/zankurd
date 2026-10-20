import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_glyphs.dart';

enum _SahneButtonKind { primary, secondary, text, tonal }

/// Şahnê düğmesi — maketteki "1 · Düğme".
///
/// * [SahneButton.primary] — Agir dolgu, koyu metin, isteğe bağlı ok,
///   ekrandaki TEK bulanık gölge (`0 8 24 -8`). Ekranda tek birincil.
///   Uygulamanın `FilledButton` temasına dayanır.
/// * [SahneButton.secondary] — ŞEFFAF dolgu + 1,5 px görünür kenar
///   (`secondaryEdge`) + güçlü etiket. Düz ve gölgesizdir (yükselti 0).
/// * [SahneButton.tonal] — MOD RENGİNDE ton dolgu ([tint]) + mod renginde
///   etiket ([foreground]), kenarsız (2026-10-20 renk ve canlılık işi).
///   Çerçeveli gri ikincil düğmeler ("Oyna", "Oda kur", "Kodla katıl")
///   hiçbir moda ait görünmüyordu; tonal düğme hangi modda olduğunu renkle
///   söyler (düello Boyax, arkadaş/oda Nîl, öğrenme Zimrût). Ekranın
///   birincil eylemi yine Agir'dir; tonal düğme onunla yarışmaz.
/// * [SahneButton.text] — Agir metni (`actTx`) + chevron; görsel 44,
///   dokunma alanı 48 ([sahneTapTarget], `MaterialTapTargetSize.padded`).
/// * Pasif — `onPressed: null`: opaklık değil ortak DÜZ soluk dolgu
///   (`disabledFill`) + soluk etiket (`disabledFg`), KENARSIZ; gölge yok.
///   Kurul 3. tur 2026-10-20: ikincil (kenarlı, şeffaf) ile pasif (kenarsız,
///   dolgulu) ayrı okunur; eskiden ikisi de soluk gri-mavi dolguydu.
/// * Yükleniyor — [loading]: etiketin yerinde 20'lik döner gösterge; düğme
///   görünüşünü korur (pasifleşmez, sözü değişmez) ama dokunuşu yok sayar.
///
/// Etiketin solunda ikon ([icon], Lucide) ya da serbest bir öncül
/// ([leading], ör. jeton fiyatı için `SahneGlyph`). [buttonKey] içteki
/// Material düğmesine verilir: testler ve ekran sözleşmeleri düğmenin
/// kendisini (`FilledButton` / `TextButton`) bulabilsin.
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
    this.leading,
    this.arrow = true,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.buttonKey,
  }) : quiet = false,
       tint = null,
       foreground = null,
       _kind = _SahneButtonKind.primary;

  const SahneButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.arrow = false,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.buttonKey,
  }) : quiet = false,
       tint = null,
       foreground = null,
       _kind = _SahneButtonKind.secondary;

  const SahneButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    required Color this.tint,
    required Color this.foreground,
    this.icon,
    this.leading,
    this.arrow = false,
    this.expand = false,
    this.loading = false,
    this.semanticLabel,
    this.buttonKey,
  }) : quiet = false,
       _kind = _SahneButtonKind.tonal;

  const SahneButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.arrow = true,
    this.quiet = false,
    this.icon,
    this.semanticLabel,
    this.buttonKey,
  }) : _kind = _SahneButtonKind.text,
       tint = null,
       foreground = null,
       leading = null,
       loading = false,
       expand = false;

  final _SahneButtonKind _kind;
  final String label;

  /// Yalnız tonal düğme: ton dolgusu ve etiket/ikon rengi.
  final Color? tint;
  final Color? foreground;

  /// `null` → pasif.
  final VoidCallback? onPressed;

  /// Etiketin solundaki ikon (Lucide).
  final IconData? icon;

  /// Etiketin solundaki serbest öncül (ör. `SahneGlyph` jeton); [icon]
  /// yerine geçer.
  final Widget? leading;

  /// Yükleniyor: etiketin yerinde döner gösterge, dokunuş yok sayılır.
  final bool loading;

  /// İçteki Material düğmesinin anahtarı.
  final Key? buttonKey;

  /// Birincilde sağda ok (→), metin düğmesinde chevron (›).
  final bool arrow;

  /// Yalnız metin düğmesi: ikincil metin rengi (turuncu vurgu yok). Aynı
  /// satırdaki birincil metin eylemiyle ("Teste başla") yarışmasın diye
  /// "Şimdilik geç" gibi vazgeçme bağlantıları için.
  final bool quiet;

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

    // İkon ve ok ETİKETİN İLK SATIRINA hizalanır: iki satıra saran etikette
    // ortada dikey ortalanan ikon, kısa ikinci satırın yanında sahipsiz
    // kalıyordu (320 px / 2×, "Dest bi pêşbirkê bike").
    final lineStyle = isText ? SahneType.captionStrong : SahneType.button;
    final lineHeight = math.max(
      iconSize,
      MediaQuery.textScalerOf(
        context,
      ).scale((lineStyle.fontSize ?? 16) * (lineStyle.height ?? 1.5)),
    );
    Widget onFirstLine(Widget child) => SizedBox(
      height: lineHeight,
      child: Center(child: child),
    );

    final lead = leading ?? (icon == null ? null : Icon(icon, size: iconSize));
    final Widget content = loading
        ? SizedBox.square(
            dimension: 20,
            child: Builder(
              builder: (context) => CircularProgressIndicator(
                strokeWidth: 2.5,
                color: IconTheme.of(context).color,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lead != null) ...[onFirstLine(lead), SizedBox(width: gap)],
              // `longestLine`: iki satıra sarınca metin kutusu en uzun satıra
              // daralır; yoksa kutu bütün boşluğu kaplar, ikon düğmenin
              // soluna yapışır, ortadaki metinden kopardı (320 px / 2×).
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  textWidthBasis: TextWidthBasis.longestLine,
                ),
              ),
              if (arrow) ...[
                SizedBox(width: gap),
                onFirstLine(
                  Icon(
                    isText ? AppIcons.chevronRight : AppIcons.arrowRight,
                    size: iconSize,
                  ),
                ),
              ],
            ],
          );
    // Yüklenirken düğme görünüşünü korur ama dokunuşu yok sayar.
    final VoidCallback? press = loading
        ? (onPressed == null ? null : () {})
        : onPressed;

    WidgetStateProperty<BorderSide?> side(
      BorderSide rest, {
      bool disabledBorder = true,
    }) => WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.focused)) {
        return BorderSide(
          color: t.tx,
          width: SahneRing.r2,
          strokeAlign: BorderSide.strokeAlignInside,
        );
      }
      if (disabledBorder && s.contains(WidgetState.disabled)) {
        return BorderSide.none;
      }
      return rest;
    });

    Widget button;
    switch (_kind) {
      case _SahneButtonKind.primary:
        button = FilledButton(
          key: buttonKey,
          onPressed: press,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(52, 52)),
            // Pasif birincil: soluk Kulis dolgusu (`s2`, temadan) + üçüncül
            // etiket, KENARSIZ (`backgroundColor` burada yazılmaz: Agir
            // dolgu bekçisi temadan gelen dolguyu sayar). Eskiden Perde (`s1`, gündüz beyaz) + `edge` çerçeve
            // beyaz bir "ikincil" düğme gibi okunuyordu (oda lobisi, tek
            // oyuncu: "Yarışı başlat" etkin sanıldı).
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
          key: buttonKey,
          onPressed: press,
          style:
              FilledButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                foregroundColor: t.tx,
                disabledBackgroundColor: t.disabledFill,
                disabledForegroundColor: t.disabledFg,
                minimumSize: const Size(52, 52),
                textStyle: SahneType.button,
                shape: SahneShape.m,
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: SahneSpace.x3,
                ),
              ).copyWith(
                // Kurul 3. tur: ikincil = şeffaf + 1,5 px görünür kenar (her
                // iki temada); pasiften (kenarsız dolgu) bu ayırır.
                side: side(
                  BorderSide(
                    color: t.secondaryEdge,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
              ),
          child: content,
        );
      case _SahneButtonKind.tonal:
        button = FilledButton(
          key: buttonKey,
          onPressed: press,
          style: FilledButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: tint,
            foregroundColor: foreground,
            disabledBackgroundColor: t.disabledFill,
            disabledForegroundColor: t.disabledFg,
            minimumSize: const Size(52, 52),
            textStyle: SahneType.button,
            shape: SahneShape.m,
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: SahneSpace.x3,
            ),
          ).copyWith(side: side(BorderSide.none, disabledBorder: true)),
          child: content,
        );
      case _SahneButtonKind.text:
        button = TextButton(
          key: buttonKey,
          onPressed: press,
          style: TextButton.styleFrom(
            foregroundColor: quiet ? t.tx2 : t.linkTx,
            disabledForegroundColor: t.tx3,
            minimumSize: const Size(44, 44),
            textStyle: SahneType.captionStrong,
            shape: SahneShape.m,
            padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x1),
            // Görsel 44, dokunma alanı 48: Material düğmesi 44'lük yüzeyi
            // 48'lik bir dokunma kutusunun ortasına koyar.
            tapTargetSize: MaterialTapTargetSize.padded,
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
        onTap: press,
        child: button,
      );
    }
    return button;
  }
}

/// Joker düğmesi — ikincilin kompakt çeşidi (maketteki `.sh-jk`).
///
/// 2026-10-19 sadeleşme: KAPSÜL çip (görsel 40, dokunma kutusu 48), ikon +
/// jeton glifi + fiyat. Eskiden 52'lik köşeli düğmeydi. Jetonu yetmeyen
/// joker aynı kapsülde ikon + etiket %50 opaklıkta, fiyat ikincil metinle okunur (kilit simgesi yok),
/// dokunulabilir. (Önceki belge:) Ortada ikon + jeton glifi + fiyat (Zêr metni). Adı
/// ekranda yazmaz: ekran okuyucu "ad, fiyat"ı okur, uzun basışta ipucu
/// olarak görünür. Dar ekranda ve büyük yazıda içerik sığdırılarak küçülür
/// (taşmaz). Hâller:
///
/// * Etkin — `onPressed` verilir.
/// * Seçili ([selected]; ör. bu soruda açılmış "Çift Cevap"): Zêr tonu +
///   Halka 2 altın, ikon altın; fiyat yerine ✓ — joker zaten ödendi.
///   Ekran okuyucu seçili durumunu duyar.
/// * Jeton yetmiyor ([unaffordable]): pasif (Perde + üçüncül ikon) ama
///   fiyat GÖRÜNÜR, üçüncül metinle — oyuncu neden alamadığını görür.
/// * Pasif (`onPressed: null`; kullanıldı, cevap verildi): Perde +
///   üçüncül ikon, fiyat gizli, opaklık yok.
class SahneJokerButton extends StatelessWidget {
  const SahneJokerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.price,
    required this.onPressed,
    this.semanticLabel,
    this.selected = false,
    this.unaffordable = false,
  });

  final IconData icon;

  /// Jokerin adı (ör. "Nîv bi Nîv"): Semantics ve uzun basış ipucu.
  final String label;
  final int price;
  final VoidCallback? onPressed;

  /// Varsayılan: "ad, fiyat".
  final String? semanticLabel;

  /// Bu soruda açılmış joker.
  final bool selected;

  /// Jeton yetmiyor: pasif görünür ama fiyatı gösterir.
  final bool unaffordable;

  /// Kapsülün görsel boyu; dokunma kutusu [sahneTapTarget] (48).
  static const double visualHeight = 48;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Jetonu yetmeyen joker SOLUK çizilir ama dokunulabilir kalır (neden
    // alınamadığı söylensin): `unaffordable` görünümü, `onPressed` dokunmayı
    // belirler. Etkin = hem dokunulabilir hem alınabilir.
    final tappable = onPressed != null;
    final enabled = tappable && !unaffordable;
    // Jeton yetmiyorsa kapsül AYNI kalır; ikon ve etiket %50 opaklıkta, kenarsız, ortak pasif dolguda
    // çizilir (kilit simgesi jeton glifinin yerine geçer: kalabalık olmasın).
    Color dim(Color c) => c.withValues(alpha: 0.5);
    final fg = selected ? t.goldTx : (enabled ? t.tx : dim(t.tx));
    final showPrice = !selected && (enabled || unaffordable);
    // Kurul incelemesi 2026-10-19: kapsül gecede zemine karışıyordu (4 model).
    // Etkin ve pasif kapsül 1 px görünür kenar taşır; ikon tam karşıtlıkta.
    final capsule = StadiumBorder(
      side: selected
          ? BorderSide(
              color: t.goldTx,
              width: SahneRing.r2,
              strokeAlign: BorderSide.strokeAlignInside,
            )
          : (enabled ? BorderSide(color: t.tx3) : BorderSide.none),
    );
    // Ad etiketi (ikonun altında, tek satır, sığmazsa küçülür); büyük
    // yazıda (≥ %130) gizlenir, ad Semantics'te bütündür.
    final showLabel = MediaQuery.textScalerOf(context).scale(14) < 18.2;
    return Semantics(
      container: true,
      button: true,
      enabled: tappable,
      selected: selected ? true : null,
      label: semanticLabel ?? '$label, $price',
      onTap: tappable ? onPressed : null,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        triggerMode: TooltipTriggerMode.longPress,
        excludeFromSemantics: true,
        child: SahnePressSink(
          enabled: enabled,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: sahneTapTarget),
            // Dokunma kutusu en az 48.
            // Etiket eklenince kapsül 48'in üstüne uzayabilir.
            child: Center(
              heightFactor: 1,
              child: SahneTappable(
                shape: capsule,
                // Jetonu yetmeyen joker ortak pasif dolguyu (Perde `s1`) alır:
                // yalnız soluk metin onu "etkin ama silik" gösteriyordu.
                color: selected
                    ? t.goldTint
                    : (unaffordable ? t.disabledFill : t.s2),
                onTap: tappable ? onPressed : null,
                child: ConstrainedBox(
                  // a11y-tap-target: noninteractive — görsel kapsül tabanı;
                  // dokunma hedefi dıştaki 48'lik kutudur.
                  constraints: const BoxConstraints(
                    minHeight: visualHeight,
                    minWidth: 52,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SahneSpace.x2,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 20, color: fg),
                                if (selected) ...[
                                  const SizedBox(width: SahneSpace.x1),
                                  Icon(
                                    AppIcons.check,
                                    size: 16,
                                    color: t.goldTx,
                                  ),
                                ],
                                if (showPrice) ...[
                                  const SizedBox(width: SahneSpace.x1),
                                  // Kurul 2. tur (2026-10-20): sıfır bakiyede
                                  // pasif joker hâlâ "etkin" okunuyordu (üç
                                  // model). Jeton glifi yerine KİLİT: fiyatın
                                  // yanındaki kilit "alınamaz"ı söyler,
                                  // soluk dolgu tek başına söylemiyordu.
                                  if (unaffordable)
                                    Icon(
                                      AppIcons.lock,
                                      key: const ValueKey('joker-locked-glyph'),
                                      size: 14,
                                      color: t.tx2,
                                    )
                                  else
                                    const SahneGlyph(
                                      SahneGlyphKind.coin,
                                      size: 16,
                                      filled: true,
                                    ),
                                  const SizedBox(width: SahneSpace.x1),
                                  Text(
                                    '$price',
                                    style: SahneType.captionStrong.copyWith(
                                      color: enabled ? t.goldTx : t.tx2,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (showLabel)
                              Text(
                                label,
                                maxLines: 1,
                                style: SahneType.caption.copyWith(
                                  color: selected
                                      ? t.goldTx
                                      : (enabled
                                            ? t.tx2
                                            : t.tx2.withValues(alpha: 0.75)),
                                  // ≥ 13: 11 px etiket kurulda okunmadı.
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
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
