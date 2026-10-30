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
/// 2026-10-19 sadeleşme: kapsül çip (40 boy, 48'lik dokunma kutusunda);
/// ikon + jeton + fiyat. Jetonu yetmeyen joker soluk ve küçük bir kilitle
/// çizilir, dokunulabilir kalır ([onLockedTap]).
///
/// (Önceki hâl) 52 boy, Kulis tonu; ortada jokerin ikonu + jeton glifi + fiyat. Jokerin
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
    this.onLockedTap,
    this.free = false,
    this.unavailable = false,
    this.secondTry = false,
    super.key,
  });

  /// Kurul 3 D19 (3/3): yazılı cevap ve cümle sıralama sorularında "Çift
  /// cevap" adı ne yaptığını söylemiyordu (iki şık seçilmez; yanlışsa bir
  /// deneme daha verilir). Bu türlerde joker "İkinci deneme" adını taşır;
  /// mantık aynı.
  final bool secondTry;

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isUsed;
  final bool isAnswered;
  final bool isActive;
  final bool cantAfford;

  /// W1: günlük bedava hak açık; fiyat yuvasında "Bedava" yazar.
  final bool free;

  /// Bu soruda anlamsız (ör. iki şıklı sorudaki Şık İpucu: %50/%50 gösterir
  /// ve ücretsiz hakkı boşa harcar). Pasif çizilir; sebep ekran okuyucuya
  /// ve [onLockedTap] tostuna gider (2026-10-29, X6).
  final bool unavailable;
  final VoidCallback onTap;

  /// Jetonu yetmeyen joker soluk + kilitli çizilir ama DOKUNULABİLİR kalır:
  /// dokununca neden alınamadığı söylenir. `null` → dokunulamaz.
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final canTap = isEnabled && !unavailable;
    final lockedTap = (cantAfford || unavailable) && !canTap
        ? onLockedTap
        : null;

    final stateLabel = isActive
        ? context.t(K.wildcardActive)
        : isUsed
        ? context.t(K.wildcardUsed)
        : isAnswered
        ? context.t(K.locked)
        : unavailable
        ? context.t(K.wildcardUnavailableTwoOptions)
        : cantAfford
        ? context.t(K.wildcardNoCoins)
        : null;

    final typeLabel = secondTry && type == WildcardType.doubleAnswer
        ? context.t(K.wildcardSecondTry)
        : type.label(isKu);
    final typeHint = switch (type) {
      WildcardType.fiftyFifty => context.t(K.wildcardFiftyHint),
      WildcardType.audience => context.t(K.wildcardAudienceHint),
      WildcardType.doubleAnswer => context.t(K.wildcardDoubleHint),
      WildcardType.changeQuestion => context.t(K.wildcardChangeHint),
    };
    // W1 (2026-10-28 tur 5): hak açıkken fiyat yuvası "Bedava" yazar (aynı
    // boy/stil, rozet değil); ayrı "Bugün 1 joker bedava" çipi kalktı.
    final price = free
        ? context.t(K.freeWord)
        : '${type.coinCost} ${context.t(K.coinWord)}';
    final displayLabel = stateLabel == null
        ? '$typeLabel • $price'
        : '$typeLabel • $stateLabel';
    final hintMessage = stateLabel == null
        ? typeHint
        : '$typeHint • $stateLabel';

    return Semantics(
      button: true,
      enabled: canTap || lockedTap != null,
      selected: isActive,
      label: displayLabel,
      hint: hintMessage,
      excludeSemantics: true,
      onTap: canTap ? onTap : lockedTap,
      child: SahneJokerButton(
        icon: type.icon,
        label: typeLabel,
        price: type.coinCost,
        semanticLabel: displayLabel,
        // Bu soruda açılmış joker (Çift Cevap) seçili hâlde durur; jeton
        // yetmeyen joker pasif ama fiyatını gösterir (neden alınamadığı
        // görünsün).
        selected: isActive,
        unaffordable: cantAfford || unavailable,
        free: free,
        freeLabel: context.t(K.freeWord),
        onPressed: canTap ? onTap : lockedTap,
      ),
    );
  }
}
