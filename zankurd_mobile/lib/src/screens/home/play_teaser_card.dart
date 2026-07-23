import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../../widgets/bouncing_button.dart';

/// Ana sayfadan Pêşbazî (Oyna) sekmesine kısa geçiş kartı — [home_screen.dart]
/// yorumundaki "kısa teaser" sözü, [DailyRaceCard] ile aynı tek-satır kart
/// kalıbını kullanır (Pirs sadeliği: ayrı 2x2 mod grid'i tekrarlamaz).
class PlayTeaserCard extends StatelessWidget {
  const PlayTeaserCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Semantics(
      key: const ValueKey('home-play-teaser'),
      button: true,
      label: ku ? 'Zû bilîze' : 'Hemen oyna',
      // 2026-07-23 canlı UX denetimi: içerideki başlık Text'i label'la
      // aynı metni taşıyıp çift okunuyordu (M28 devamı).
      excludeSemantics: true,
      child: BouncingButton(
        onPressed: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.all(20),
              // Kart zemini şeffaftı: açık temada sayfa zeminiyle
              // neredeyse aynı, koyu temada fark ~%2 kalıyordu ve kart
              // tıklanabilir görünmüyordu (2026-07-22 canlı UX denetimi).
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.culturalBrandBg.withValues(alpha: 0.35),
                ),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.culturalBrandBg.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.gamepad,
                      color: AppTheme.culturalBrandBg,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ku ? 'Zû bilîze' : 'Hemen oyna',
                          style: AppTypography.heading2.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ku
                              ? 'Duel, oda an çerx — hemû li Pêşbazîyê.'
                              : 'Düello, oda veya çark — hepsi Yarış\'ta.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSubColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    color: AppTheme.culturalBrandBg,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
