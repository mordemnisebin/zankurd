import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/wildcard.dart';
import '../../widgets/sahne/sahne.dart';

/// Quiz joker düğmesi (50/50, Şık İpucu, Çift Cevap, Soru Değiştir) —
/// Şahnê joker düğmesinin ([SahneJokerButton]) quiz bağlantısı.
///
/// ## Görünüm
///
/// 52 boy, Kulis tonu; ortada jokerin ikonu + jeton glifi + fiyat. Jokerin
/// ADI ekranda yazmaz: ekran okuyucu "ad • durum" okur, uzun basışta ad
/// ipucu olarak görünür. Bu yüzden Kurmancî adların dar sütunda kırpılması
/// ("Alîkariya Be…", 2026-08-16) artık olamaz — kırpılacak görünür etiket
/// yoktur; ad Semantics'te bütündür (bkz. `wildcard_label_truncation_test`).
///
/// Kullanılamayan joker (kullanıldı, cevap verildi) Şahnê pasif hâlidir:
/// Perde + üçüncül ikon, fiyat gizli, opaklık yok. Jeton yetmeyen joker de
/// pasiftir ama fiyatı üçüncül metinle GÖRÜNÜR; bu soruda açılmış joker
/// (Çift Cevap) seçili hâldedir (Zêr halka + ✓). Durumun SÖZÜ ekran
/// okuyucuya gider ("Çift Cevap • Etkin", "… • Yetersiz bakiye").
///
/// Ekranda fiyat sayı + jeton glifidir. Ekran okuyucu fiyatı para
/// biriminin tam adıyla duyurur (`K.coinWord`, ör. "20 jeton").
///
/// 2026-09-29 doğallık: duyuru defterdeki kısaltmayla ("20j") yapılıyordu;
/// "yirmi j" diye okunan bir harf bilgi değildir. Kısaltma hiçbir yerde
/// gösterilmez.
class WildcardButton extends StatelessWidget {
  const WildcardButton({
    required this.type,
    required this.isKu,
    required this.isEnabled,
    required this.isUsed,
    required this.isAnswered,
    required this.isActive,
    required this.onTap,
    this.cantAfford = false,
    super.key,
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isUsed;
  final bool isAnswered;
  final bool isActive;
  final bool cantAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = isEnabled;

    final stateLabel = isActive
        ? context.t(K.wildcardActive)
        : isUsed
        ? context.t(K.wildcardUsed)
        : isAnswered
        ? context.t(K.locked)
        : cantAfford
        ? context.t(K.insufficientBalance)
        : null;

    final typeLabel = type.label(isKu);
    final typeHint = switch (type) {
      WildcardType.fiftyFifty => context.t(K.wildcardFiftyHint),
      WildcardType.audience => context.t(K.wildcardAudienceHint),
      WildcardType.doubleAnswer => context.t(K.wildcardDoubleHint),
      WildcardType.changeQuestion => context.t(K.wildcardChangeHint),
    };
    final price = '${type.coinCost} ${context.t(K.coinWord)}';
    final displayLabel = stateLabel == null
        ? '$typeLabel • $price'
        : '$typeLabel • $stateLabel';
    final hintMessage = stateLabel == null
        ? typeHint
        : '$typeHint • $stateLabel';

    return Semantics(
      button: true,
      enabled: canTap,
      selected: isActive,
      label: displayLabel,
      hint: hintMessage,
      excludeSemantics: true,
      onTap: canTap ? onTap : null,
      child: SahneJokerButton(
        icon: type.icon,
        label: typeLabel,
        price: type.coinCost,
        semanticLabel: displayLabel,
        // Bu soruda açılmış joker (Çift Cevap) seçili hâlde durur; jeton
        // yetmeyen joker pasif ama fiyatını gösterir (neden alınamadığı
        // görünsün).
        selected: isActive,
        unaffordable: cantAfford,
        onPressed: canTap ? onTap : null,
      ),
    );
  }
}
