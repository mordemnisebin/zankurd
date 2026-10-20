import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import 'sahne/sahne.dart';

/// İki parçalı KU | TR dil seçici.
///
/// ## Neden ortak
///
/// Giriş ekranı bu görünümü zaten kullanıyordu. Tanıtım turu ise ayrı,
/// tek yuvarlak bir hapla (yalnız o anki dili yazan) aynı işi yapıyordu —
/// hangi dile NASIL geçileceği görünmüyordu, yalnız hangi dilde
/// OLDUĞUN yazıyordu (2026-09-27 canlı gezinti). İki ayrı bileşen aynı
/// kararı iki kez (ve farklı) uygulamasın diye kod tek yerde durur;
/// çağıran ekran yalnız her çipin `ValueKey`'ini verir.
///
/// Tur 8: iki ayrı çip değil TEK bitişik segment (aşağıda `build` notu).
///
/// 2026-09-29 Şahnê (eski): seçim rayının sığan çeşidi ([SahneRail.fit] +
/// [SahneRailChip]) — iki eşit çip, 8 aralık; seçili çip nötr rolün tonu
/// + Halka 2, öteki Perde + kenar. Boyu içeriğe göre sabittir (120 × 48):
/// bu kap bazı ekranlarda Stack/Align'ın gevşek ama sınırlı kısıtı altında
/// durur ve alanın tamamına yayılmamalıdır (onboarding_screen.dart
/// 2026-09-10 notu). Dokunma alanı 48.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({required this.kuKey, required this.trKey, super.key});

  /// "KU" çipinin test/erişilebilirlik anahtarı.
  final Key kuKey;

  /// "TR" çipinin test/erişilebilirlik anahtarı.
  final Key trKey;

  /// Toplam boy ve genişlik: tek bitişik segment (tur 8).
  static const double width = 120;
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final t = SahneTokens.of(context);
    // Tur 8 (3 denetçi): iki ayrı düğme (biri dolu, biri çerçeveli) gibi
    // okunuyordu; "dil seçici" değil iki bağımsız eylem sanılıyordu. Artık
    // TEK bitişik segment: ortak 1 px dış kenar, ortada ince ayraç, seçili
    // yarı ortak seçili stille (selFill + selTx) dolu.
    return SizedBox(
      key: const ValueKey('language-toggle-segment'),
      width: width,
      height: height,
      child: DecoratedBox(
        // Kenar ÖNDE çizilir: seçili yarının dolgusu kenarı örtmesin.
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: SahneShape.withSide(SahneShape.m, t.tx2, width: 1),
        ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: SahneShape.m),
          child: ColoredBox(
            color: t.s1,
            child: Row(
              children: [
                Expanded(
                  child: _LanguageSegment(
                    chipKey: kuKey,
                    label: 'KU',
                    semanticLabel: 'Kurmancî',
                    active: isKu,
                    onTap: () => context.langProvider.setLang('ku'),
                  ),
                ),
                ColoredBox(
                  color: t.tx2,
                  child: const SizedBox(width: 1, height: double.infinity),
                ),
                Expanded(
                  child: _LanguageSegment(
                    chipKey: trKey,
                    label: 'TR',
                    semanticLabel: 'Türkçe',
                    active: !isKu,
                    onTap: () => context.langProvider.setLang('tr'),
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

class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.chipKey,
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final String semanticLabel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik ağacında bu iki buton etiketsiz görünüyordu
    // (yalnız "button"); ekran okuyucu hangi dile geçildiğini
    // söyleyemiyordu (2026-07-22 canlı UX denetimi). Görünen söz "KU",
    // okunan söz dilin adıdır.
    final t = SahneTokens.of(context);
    return KeyedSubtree(
      key: chipKey,
      child: Semantics(
        container: true,
        button: true,
        selected: active,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: active ? t.selFill : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: SahneType.captionStrong.copyWith(
                  color: active ? t.selTx : t.tx2,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
