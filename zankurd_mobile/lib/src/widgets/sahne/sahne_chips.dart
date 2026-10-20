import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';

/// Stat çipi — marka satırındaki seri/jeton, oyun sahnesindeki skor,
/// sonuçtaki ödül (maketteki `.sh-chip`).
///
/// Görsel 36 (M pah, Kulis tonu, sol 8 / sağ 12 boşluk, glif 20 + kalın
/// açıklama, tablo rakamı). [gold] ödül çeşidi: Zêr tonu + koyu altın
/// metin. Dokunulabilirse ([onTap], ör. jeton → mağaza) dokunma alanı 48
/// ([sahneTapTarget]) yüksekliğe ve en az 48 genişliğe genişler; görsel 36
/// kalır. Ekran okuyucu [semanticLabel]'ı
/// (ör. "120 jeton") okur.
class SahneStatChip extends StatelessWidget {
  const SahneStatChip({
    super.key,
    required this.leading,
    required this.label,
    this.semanticLabel,
    this.onTap,
    this.gold = false,
  });

  /// Glif (genelde `SahneGlyph`, 20).
  final Widget leading;
  final String label;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final visual = SahneTappable(
      shape: SahneShape.chamferM,
      color: gold ? t.goldTint : t.s2,
      onTap: onTap,
      child: ConstrainedBox(
        // a11y-tap-target: noninteractive — görsel çip tabanı; dokunma
        // hedefi dıştaki 48'lik kutudur (onTap yoksa salt görsel).
        constraints: const BoxConstraints(minHeight: 36),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SahneSpace.x2,
            end: SahneSpace.x3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 20, child: leading),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: Text(
                  label,
                  style: SahneType.captionStrong.copyWith(
                    color: gold ? t.goldTx : t.tx,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null
          ? visual
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: sahneTapTarget,
                  minWidth: sahneTapTarget,
                ),
                child: Center(widthFactor: 1, child: visual),
              ),
            ),
    );
  }
}

/// Seçim rayı — yatay kayan çip dizisi (maketteki `.sh-seg`).
///
/// Sayfa kenarına taşar: rayı sayfa boşluğu OLMADAN yerleştir, kendi
/// 16'lık kenarını kendisi verir. Sağ kenardaki 32 px solma
/// kaydırılabilirliği söyler ([fadeColor] zemin rengi; varsayılan `bg`).
/// [SahneRail.fit]: sığan çeşit — çipler eşit genişlikte, solma yok
/// (ör. Sıralama dönemleri); sayfa boşluğunun İÇİNE konur. Büyük yazıda
/// (≥ %150) sığan ray iki sütuna geçer: dört çip tek satırda o kadar
/// küçülüyordu ki "Arkadaş" okunmuyordu.
///
/// Çiplerin 48'lik dokunma kutusu görselden her yanda 2 taşar; ray bu payı
/// aralıktan düşer, çipler arasında görsel boşluk yine 8'dir.
class SahneRail extends StatelessWidget {
  const SahneRail({super.key, required this.children, this.fadeColor})
    : fit = false;

  const SahneRail.fit({super.key, required this.children})
    : fit = true,
      fadeColor = null;

  final List<Widget> children;
  final bool fit;
  final Color? fadeColor;

  /// Çiplerin arası: görsel 8, eksi iki dokunma payı.
  static const double _gap = SahneSpace.x2 - 2 * SahneRailChip.inset;

  /// Çip sığan rayın içinde mi?
  static bool isFitted(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FitRailScope>() != null;

  @override
  Widget build(BuildContext context) {
    if (fit) {
      Widget row(List<Widget> items) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(child: items[i]),
            ],
          ],
        ),
      );
      final large = MediaQuery.textScalerOf(context).scale(14) >= 21;
      if (!large || children.length < 3) {
        return _FitRailScope(child: row(children));
      }
      return _FitRailScope(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += 2) ...[
              if (i > 0) const SizedBox(height: _gap),
              row([
                children[i],
                if (i + 1 < children.length)
                  children[i + 1]
                else
                  const SizedBox.shrink(),
              ]),
            ],
          ],
        ),
      );
    }
    final fade = fadeColor ?? SahneTokens.of(context).bg;
    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.page - SahneRailChip.inset,
          ),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                children[i],
              ],
            ],
          ),
        ),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          end: 0,
          width: SahneSpace.x8,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [fade.withValues(alpha: 0), fade],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FitRailScope extends InheritedWidget {
  const _FitRailScope({required super.child});

  @override
  bool updateShouldNotify(_FitRailScope oldWidget) => false;
}

/// Seçim rayı çipi (maketteki `.sh-seg-it`).
///
/// Görsel 44, dokunma alanı 48 (her yanda [inset] kadar saydam pay); M pah,
/// Perde + kenar, ikincil metin. Perde bir kartın İÇİNDE ([SahneOnSurface])
/// seçili olmayan çip bir basamak yükselir (Kulis): Perde üstünde Perde
/// görünmüyordu. Seçili: rolün tonu + Halka 2 rol metni rengiyle, metin
/// rol rengi. Ekran okuyucu seçili durumunu okur. Metin sığmazsa sarar,
/// çip uzar.
class SahneRailChip extends StatelessWidget {
  /// Seçili ve seçilmemiş çipin halka kalınlığı (ikisi AYNI: boyut oynamaz).
  static const double railChipRing = 1;

  const SahneRailChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.role = SahneRole.learn,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final SahneRole role;

  /// Dokunma kutusunun görselden her yandaki payı.
  static const double inset = (sahneTapTarget - 44) / 2;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fitted = SahneRail.isFitted(context);
    final onSurface = SahneOnSurface.of(context);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: fitted ? 1 : null,
      style: SahneType.captionStrong.copyWith(
        color: selected ? t.selTx : t.tx2,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
      ),
    );
    // Tur 10b (Gemini + ChatGPT): seçili olmayan çip s1 (kartla aynı beyaz)
    // idi, düz metin gibi duruyordu; seçili olan da ders çerçevesi ve Başla
    // ile aynı güçlü turuncuyu (2 px) paylaşıyordu. Seçilmemiş çip artık
    // nötr dolgulu (s2); seçili çip turuncu metin + açık turuncu dolgu + 1 px
    // çerçeve: ana eylemden sakin.
    final fill = selected ? t.selFill : (onSurface ? t.s3 : t.s2);
    // Seçili olmayan çip de AYNI kalınlıkta halka taşır; halkası kendi
    // zeminin rengindedir (görünmez). Eskiden 1 px'lik soluk bir kenar vardı:
    // gündüzde sayfa zeminiyle birleşip beyaz alanı küçültüyor, seçilince
    // Halka 2 çipi "büyütüyordu" (2026-10-01 tasarım denetimi: 88 ↔ 82 px).
    // İki hâlde de dolu alan aynı 44'ü kaplar; fark yalnız halkanın rengi.
    final shape = SahneShape.withSide(
      SahneShape.m,
      selected ? t.selLine : fill,
      width: railChipRing,
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          // Dokunma kutusu 48: görsel 44 + her yanda [inset] saydam pay.
          constraints: const BoxConstraints(
            minHeight: sahneTapTarget,
            minWidth: sahneTapTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.all(inset),
            child: SahneTappable(
              shape: shape,
              color: fill,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: fitted ? SahneSpace.x2 : SahneSpace.x4,
                  vertical: SahneSpace.x1,
                ),
                child: Center(
                  widthFactor: 1,
                  child: fitted
                      // Sığan rayda genişlik sabittir: söz bölünmesin diye
                      // tek satırda küçülerek sığar (kesilmez).
                      ? FittedBox(fit: BoxFit.scaleDown, child: text)
                      : text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rozetin tonu.
enum SahneBadgeTone { race, learn, gold, soon }

/// Rol rozeti — "Bugün", "Sana önerilen", "Yakında" (maketteki `.sh-tag`).
///
/// 24, S pah, ton zemin + rol metni; açıklama kalını ([SahneType.captionStrong]),
/// metin verildiği gibi (cümle düzeni). Dolu kırmızı rozet YOK: dikkat rengi
/// değil, rol rengi taşır. Metin kesilmez; sığmazsa sarar.
///
/// 2026-09-29 doğallık (K8): rozet eskiden büyük harf + harf aralığıyla
/// (Etiket biçemi) yazılıyordu. Her rozet bağırınca şablon izi bırakıyordu;
/// büyük harf yalnız soru ekranının künyesinde kalır.
class SahneBadge extends StatelessWidget {
  const SahneBadge({
    super.key,
    required this.label,
    this.tone = SahneBadgeTone.learn,
  });

  final String label;
  final SahneBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (bg, fg) = switch (tone) {
      SahneBadgeTone.race => (t.raceTint, t.raceTx),
      SahneBadgeTone.learn => (t.eyebrowFill, t.eyebrowTx),
      SahneBadgeTone.gold => (t.goldTint, t.goldTx),
      SahneBadgeTone.soon => (t.s2, t.tx2),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
        child: ConstrainedBox(
          // a11y-tap-target: noninteractive — rol rozeti; salt görsel,
          // dokunma hedefi değil.
          constraints: const BoxConstraints(minHeight: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: SahneType.captionStrong.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Durum rozeti — Rast / Şaş (maketteki `.sh-badge`).
///
/// 32, M pah; ✓ ya da ✗ ikonu + söz ("Doğru" / "Yanlış"). Durum hiçbir
/// zaman yalnız renkle verilmez: şekil (✓/✗) ve söz her zaman birliktedir.
/// [SahneStatusBadge.square]: sözsüz 28'lik durum karesi (S pah; sonuç
/// listesi) — söz yine ekran okuyucuya gider.
///
/// [SahneStatusBadge.blank]: nötr "boş" durumu (cevapsız bırakılan soru) —
/// Rast da Şaş da değil: Kulis tonu + kum saati + ikincil metin. Aynı ölçü.
class SahneStatusBadge extends StatelessWidget {
  const SahneStatusBadge({
    super.key,
    required bool this.correct,
    required this.label,
  }) : square = false;

  const SahneStatusBadge.square({
    super.key,
    required bool this.correct,
    required this.label,
  }) : square = true;

  const SahneStatusBadge.blank({
    super.key,
    required this.label,
    this.square = false,
  }) : correct = null;

  /// `null` → nötr "boş".
  final bool? correct;

  /// Söz ("Doğru" / "Yanlış" / "Boş"); karede yalnız ekran okuyucuya.
  final String label;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (bg, fg, glyph) = switch (correct) {
      true => (t.okTint, t.okTx, AppIcons.check),
      false => (t.errTint, t.errTx, AppIcons.xmark),
      null => (t.s2, t.tx2, AppIcons.hourglass),
    };
    final icon = Icon(glyph, size: square ? 22 : 16, color: fg);
    final Widget body;
    if (square) {
      body = DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
        child: SizedBox.square(dimension: 36, child: Center(child: icon)),
      );
    } else {
      body = DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.chamferM),
        child: ConstrainedBox(
          // a11y-tap-target: noninteractive — durum rozeti; salt görsel,
          // dokunma hedefi değil.
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: SahneSpace.x2,
              end: SahneSpace.x3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    label,
                    style: SahneType.captionStrong.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(label: label, excludeSemantics: true, child: body);
  }
}

/// Seçim çipi — bir gruptan seçme (oda kurma: konu, soru sayısı, süre,
/// oyuncu, ücret). Seçili = ortak seçili stili (`SahneTokens.selFill/selLine/selTx`: turuncu ton + çizgi + koyu turuncu metin); seçilmemiş = saydam
/// zemin + ince çerçeve.
///
/// 2026-10-19 sadeleşme (ikinci tur): Material `ChoiceChip`/`FilterChip`
/// seçili ve seçilmemiş hâli yalnız ton farkıyla ayırıyor, doğal genişlikte
/// tırtıklı satırlar çiziyordu. Bu bileşen bulunduğu hücreyi doldurur
/// (çağıran eşit sütunlu ızgara kurar), en az 48 yüksekliktedir, metin
/// ortalanır. 2026-10-19 son rötuş: metin tek satırdır (uzun ad küçülerek
/// sığar; "Bilim ve Düşünce" iki satıra sarıp satırı uzatıyordu); yalnız
/// büyük yazıda (≥ %150) iki satıra izin verilir ve çağıranın ızgarası aynı
/// satırdaki bütün çipleri eşit boya getirir. Ekran okuyucu seçili durumu okur.
class SahnePickChip extends StatelessWidget {
  const SahnePickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.semanticLabel,
    this.locked = false,
    this.looked = false,
    this.minHeight = sahneTapTarget,
  });

  /// "Bakılan" kilitli seçenek: dokunulup eksik notu açıkken kehribar çerçeve
  /// (seçili DEĞİL; seçili çip yine ayrı kalır). Not kapanınca söner.
  final bool looked;

  final String label;

  /// En az yükseklik (varsayılan 48). Yoğun sayfalarda (oda kurma) 44'e
  /// inilir; 44 dokunma tabanıdır.
  final double minHeight;

  /// Kilitli seçenek (ör. jetonu yetmeyen oda ücreti): seçilemez ama okunur.
  /// Önünde kilit ikonu, gri (`tx3`) metin ve çerçeve; dokunuş yine
  /// [onTap]'a gider (çağıran "N jeton eksik" bilgisini gösterir).
  final bool locked;

  /// Ekran okuyucunun okuyacağı tam ad; [label] kısaltılmışsa verilir.
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  /// Metnin önündeki küçük glif (ör. jeton).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final large = MediaQuery.textScalerOf(context).scale(14) >= 21;
    final shape = SahneShape.withSide(
      SahneShape.m,
      // Seçilmemiş çerçeve ikincil metin tonu (tx3 değil): tx3 çerçeve ve
      // yazı birlikte "devre dışı" okunuyordu (tur 6, 5 denetçi). Yazı tam
      // opak ana metin rengi, yükseklik >= 48 (>= 44 mantıksal).
      selected
          ? t.selLine
          : (looked ? t.shortfallTx : (locked ? t.tx3 : t.tx2)),
      width: (selected || looked) ? SahneRing.r2 : 1,
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: SahneTappable(
          shape: shape,
          color: selected ? t.selFill : Colors.transparent,
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SahneSpace.x2,
                  vertical: SahneSpace.x2,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locked) ...[
                        ExcludeSemantics(
                          child: Icon(
                            AppIcons.lock,
                            size: 14,
                            color: t.disabledFg,
                          ),
                        ),
                        const SizedBox(width: SahneSpace.x1),
                      ] else if (leading != null) ...[
                        leading!,
                        const SizedBox(width: SahneSpace.x1),
                      ],
                      Flexible(
                        child: () {
                          final text = Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: large ? 2 : 1,
                            softWrap: large,
                            overflow: TextOverflow.ellipsis,
                            style: SahneType.captionStrong.copyWith(
                              color: selected
                                  ? t.selTx
                                  : (locked ? t.disabledFg : t.tx),
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          );
                          // Normal yazıda tek satır: uzun ad ("Bilim ve Düşünce")
                          // küçülerek sığar, satır boyu bozulmaz.
                          return large
                              ? text
                              : FittedBox(fit: BoxFit.scaleDown, child: text);
                        }(),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                // Kurul 4. tur: seçili hâl renge ek olarak ✓ ile de söylenir.
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: Icon(AppIcons.check, size: 12, color: t.selTx),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kaydırma alanının alt kenarında 24 px'lik yumuşak solma: ayracın hemen
/// üstünde yarım kalan satır (oyuncu sayısı çipleri) "kesilmiş" değil
/// "kayıyor" diye okunur. Renk, sayfa yüzeyi ([color] (AppPanel dolgusu)) ile aynıdır. Dokunuşu geçirir.
///
/// 2026-10-19 cila: solma yalnız altta GERÇEKTEN içerik kaldıkça çizilir.
/// Sona gelince de çizilince sondaki ipucu metni ("Oda sahibi en az 2
/// oyuncuyla…") yüzeye karışıp soluk, düşük karşıtlıklı okunuyordu.
class SahneBottomFade extends StatefulWidget {
  const SahneBottomFade({
    super.key,
    required this.child,
    required this.color,
    this.height = 24,
    this.topHeight = 0,
  });

  final Widget child;

  /// Üst kenarda içerik başlığın altına girerken çizilen opak-saydam bant
  /// (0 = yok). Yarım kesik çip satırının ince kenarını söndürür.
  final double topHeight;

  /// Kaydırma alanının arkasındaki yüzey rengi.
  final Color color;

  /// Solma bandının yüksekliği (varsayılan 24).
  final double height;

  @override
  State<SahneBottomFade> createState() => _SahneBottomFadeState();
}

class _SahneBottomFadeState extends State<SahneBottomFade> {
  bool _more = true;
  bool _before = false;

  bool _onMetrics(ScrollMetrics m) {
    final more = m.extentAfter > 1;
    final before = m.extentBefore > 1;
    if (more != _more || before != _before) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _more = more;
            _before = before;
          });
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.color;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: Stack(
          children: [
            widget.child,
            if (_before && widget.topHeight > 0)
              Positioned(
                key: const ValueKey('sahne-fade-top'),
                left: 0,
                right: 0,
                top: 0,
                height: widget.topHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [surface, surface.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            if (_more)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [surface.withValues(alpha: 0), surface],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
