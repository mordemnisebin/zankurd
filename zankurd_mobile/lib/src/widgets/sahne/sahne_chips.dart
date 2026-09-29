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
      shape: SahneShape.m,
      color: gold ? t.goldTint : t.s2,
      onTap: onTap,
      child: ConstrainedBox(
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
        color: selected ? t.roleText(role) : t.tx2,
      ),
    );
    final shape = selected
        ? SahneShape.withSide(
            SahneShape.m,
            t.roleText(role),
            width: SahneRing.r2,
          )
        : SahneShape.withSide(SahneShape.m, t.edge, width: 1);
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
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: SahneTappable(
            shape: shape,
            color: selected ? t.roleTint(role) : (onSurface ? t.s2 : t.s1),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
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
      SahneBadgeTone.learn => (t.learnTint, t.learnTx),
      SahneBadgeTone.gold => (t.goldTint, t.goldTx),
      SahneBadgeTone.soon => (t.s2, t.tx2),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
        child: ConstrainedBox(
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
    final icon = Icon(glyph, size: 16, color: fg);
    final Widget body;
    if (square) {
      body = DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
        child: SizedBox.square(dimension: 28, child: Center(child: icon)),
      );
    } else {
      body = DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.m),
        child: ConstrainedBox(
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
