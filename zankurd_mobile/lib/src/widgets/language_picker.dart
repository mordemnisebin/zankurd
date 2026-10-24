import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import 'sahne/sahne.dart';

/// Karşılamanın tepesindeki büyük, tam adlı dil seçici.
///
/// ## Kusur
/// Küçük "KU | TR" hapı (120 × 48) ilk ekranda dil seçimi olarak
/// okunmuyordu; yeni kurulumda dil artık Türkçe başlıyor ve Kurmancî okuyan
/// kullanıcının dili bulması tek dokunuş olmalı (2026-10-24 sahip kararı).
///
/// ## Kural
/// Etiket iki dilde birlikte yazılır (hangi dilde olursa olsun okunur);
/// seçenekler tam adıyla, KURMANCÎ ÖNCE; her seçenek ≥ 56 yüksek. Seçim
/// [LanguageProvider.setLang] ile yapılır — o da `language_change`
/// analitik olayını yazar, karşılamada kaç kişinin dil değiştirdiği buradan
/// ölçülür.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({required this.kuKey, required this.trKey, super.key});

  final Key kuKey;
  final Key trKey;

  static const double segmentHeight = 56;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isKu = context.isKu;
    return Column(
      key: const ValueKey('language-picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t(K.languagePickerLabel),
          style: SahneType.captionStrong.copyWith(color: t.tx2),
        ),
        const SizedBox(height: SahneSpace.x2),
        SizedBox(
          height: segmentHeight,
          child: DecoratedBox(
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
                      child: _Segment(
                        chipKey: kuKey,
                        label: 'Kurmancî',
                        active: isKu,
                        onTap: () => context.langProvider.setLang('ku'),
                      ),
                    ),
                    ColoredBox(
                      color: t.tx2,
                      child: const SizedBox(width: 1, height: double.infinity),
                    ),
                    Expanded(
                      child: _Segment(
                        chipKey: trKey,
                        label: 'Türkçe',
                        active: !isKu,
                        onTap: () => context.langProvider.setLang('tr'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
          color: active ? t.selFill : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: SahneType.bodyStrong.copyWith(
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
