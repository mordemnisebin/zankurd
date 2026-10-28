import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Karşılamadaki büyük, tam adlı dil seçici: yan yana İKİ BÜYÜK KART.
///
/// ## Kusur
/// Küçük "KU | TR" hapı (120 × 48) ilk ekranda dil seçimi olarak
/// okunmuyordu; yeni kurulumda dil artık Türkçe başlıyor ve Kurmancî okuyan
/// kullanıcının dili bulması tek dokunuş olmalı (2026-10-24 sahip kararı).
/// 2026-10-28 kurul K10: ince segment çizgisi de "form alanı" gibi
/// duruyordu; dil seçimi artık iki büyük karttır.
///
/// ## Kural
/// Seçenekler tam adıyla, KURMANCÎ ÖNCE; her kart ≥ 96 yüksek, seçili kart
/// koyu mürekkep dolgu + açık metin + onay işareti (K15), diğeri nötr yüzey.
/// Seçim [LanguageProvider.setLang] ile yapılır — o da `language_change`
/// analitik olayını yazar, karşılamada kaç kişinin dil değiştirdiği buradan
/// ölçülür. [showLabel] kapalıysa iki dilli etiket yazılmaz (sayfa başlığı
/// aynı şeyi söylüyorsa).
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    required this.kuKey,
    required this.trKey,
    this.showLabel = true,
    super.key,
  });

  final Key kuKey;
  final Key trKey;
  final bool showLabel;

  /// Kartın boyu: ≥ 96 (büyük dokunma hedefi).
  static const double cardHeight = 96;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isKu = context.isKu;
    final kuCard = _LanguageCard(
      chipKey: kuKey,
      label: 'Kurmancî',
      active: isKu,
      onTap: () => context.langProvider.setLang('ku'),
    );
    final trCard = _LanguageCard(
      chipKey: trKey,
      label: 'Türkçe',
      active: !isKu,
      onTap: () => context.langProvider.setLang('tr'),
    );
    return Column(
      key: const ValueKey('language-picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Text(
            context.t(K.languagePickerLabel),
            style: SahneType.captionStrong.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x2),
        ],
        // Büyük yazıda (≥ 1,5×) ya da çok dar ekranda ("Kurmancî" 2× yazıda
        // yan yana kartta harf harf kırılıyordu: "Kur/man/cî", 320 pt ekran
        // turu 2026-10-28) kartlar alt alta dizilir.
        if (MediaQuery.textScalerOf(context).scale(16) >= 24)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kuCard,
              const SizedBox(height: SahneSpace.x3),
              trCard,
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: kuCard),
                const SizedBox(width: SahneSpace.x3),
                Expanded(child: trCard),
              ],
            ),
          ),
      ],
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.chipKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final shape = SahneShape.withSide(
      SahneShape.l,
      active ? t.selLine : t.edge,
      width: active ? 2 : 1,
    );
    final fg = active ? t.selTx : t.tx;
    return KeyedSubtree(
      key: chipKey,
      child: Semantics(
        container: true,
        button: true,
        selected: active,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: active ? t.selFill : t.s1,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: ConstrainedBox(
              // a11y-tap-target: kart tek başına ≥ 96 yüksek.
              constraints: const BoxConstraints(
                minHeight: LanguagePicker.cardHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(SahneSpace.x3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? AppIcons.check : AppIcons.globe,
                      size: 24,
                      color: fg,
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: SahneType.headline.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
