import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';

/// Soru metninin altında kapalı duran Türkçe çeviri şeridi.
///
/// Kapalıyken tek satırlık sakin bir düğmedir ("Türkçesini göster");
/// dokununca yerinde çeviriye dönüşür ve o soru boyunca açık kalır. Soru
/// değişince (anahtar soru kimliğini taşır) yeniden kapanır.
class PromptTranslationReveal extends StatefulWidget {
  const PromptTranslationReveal({super.key, required this.translation});

  final String translation;

  @override
  State<PromptTranslationReveal> createState() =>
      _PromptTranslationRevealState();
}

class _PromptTranslationRevealState extends State<PromptTranslationReveal> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final border = Border.all(color: t.line);
    if (_open) {
      return Semantics(
        container: true,
        label: widget.translation,
        child: ExcludeSemantics(
          child: DecoratedBox(
            key: const ValueKey('prompt-tr-open'),
            decoration: ShapeDecoration(
              shape: SahneShape.m.copyWith(side: border.top),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SahneSpace.x3,
                vertical: SahneSpace.x2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(AppIcons.language, size: 18, color: t.tx2),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(
                    child: Text(
                      widget.translation,
                      style: SahneType.body.copyWith(color: t.tx2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const ValueKey('prompt-tr-toggle'),
        onPressed: () => setState(() => _open = true),
        icon: Icon(AppIcons.eye, size: 18, color: t.tx2),
        label: Text(
          context.t(K.showTurkishTranslation),
          style: SahneType.captionStrong.copyWith(color: t.tx2),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size(sahneTapTarget, sahneTapTarget),
          shape: SahneShape.m.copyWith(side: border.top),
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x3),
        ),
      ),
    );
  }
}
