import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';

/// Süre dolduğunda gösterilen geri bildirim notu.
///
/// Şıklar zaten kilitlenir (answered=true); bu not geri bildirimi
/// netleştirir: süre bitti + doğru cevap görünür.
///
/// Şahnê: Şaş ton zemini (durum ailesi) üstünde kum saati ikonu + söz;
/// L pahlı not kartı (öğrenme notuyla aynı kalıp). Durum yalnız renkle
/// verilmez: ikon ve cümle birlikte.
class QuizTimeoutNotice extends StatelessWidget {
  const QuizTimeoutNotice({
    required this.isKu,
    required this.correctAnswer,
    super.key,
  });

  final bool isKu;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = Tr.forKu(K.sureDolduDogruCevap, isKu, {'p0': correctAnswer});
    return Semantics(
      key: const ValueKey('quiz-timeout-notice'),
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: SahneSpace.x3),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: t.errTint, shape: SahneShape.l),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SahneSpace.x3,
              SahneSpace.x3,
              SahneSpace.x4,
              SahneSpace.x3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.stopwatch, color: t.errTx, size: 24),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    label,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
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
