import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../../widgets/bouncing_button.dart';

/// Fêr Bibe sekmesinden Kategorî akışına kısa geçiş kartı. Kategorîler artık
/// ayrı bir sekme değil; bu kart onları ana ekrana bağlar ([PlayTeaserCard]
/// ile aynı tek-satır kart kalıbını kullanır).
class CategoriesTeaserCard extends StatelessWidget {
  const CategoriesTeaserCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Semantics(
      key: const ValueKey('home-categories-teaser'),
      button: true,
      label: ku ? 'Kategorî' : 'Kategoriler',
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
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.brand.withValues(alpha: 0.35),
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
                      color: AppTheme.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.tableCells,
                      color: AppTheme.brand,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ku ? 'Kategorî' : 'Kategoriler',
                          style: AppTypography.heading2.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ku
                              ? 'Mijarekê hilbijêre û tê de kûr bibe.'
                              : 'Bir konu seç ve derinleş.',
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
                  const Icon(AppIcons.chevronRight, color: AppTheme.brand),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
