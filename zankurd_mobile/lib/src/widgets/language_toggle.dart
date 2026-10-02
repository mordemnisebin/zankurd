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
/// 2026-09-29 Şahnê: seçim rayının sığan çeşidi ([SahneRail.fit] +
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

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return SizedBox(
      width: 56 * 2 + SahneSpace.x2,
      height: 48,
      child: SahneRail.fit(
        children: [
          _LanguageChip(
            chipKey: kuKey,
            label: 'KU',
            semanticLabel: 'Kurmancî',
            active: isKu,
            onTap: () => context.langProvider.setLang('ku'),
          ),
          _LanguageChip(
            chipKey: trKey,
            label: 'TR',
            semanticLabel: 'Türkçe',
            active: !isKu,
            onTap: () => context.langProvider.setLang('tr'),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
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
    return KeyedSubtree(
      key: chipKey,
      child: Semantics(
        container: true,
        button: true,
        selected: active,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: SahneRailChip(
          label: label,
          selected: active,
          role: SahneRole.neutral,
          onTap: onTap,
        ),
      ),
    );
  }
}
