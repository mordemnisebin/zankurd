import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/shimmer_glow.dart';

class DailyQuizCard extends StatelessWidget {
  const DailyQuizCard({
    required this.isKu,
    required this.loading,
    required this.onPlay,
    super.key,
  });

  final bool isKu;
  final bool loading;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      glass: true,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          InkWell(
            onTap: loading ? null : onPlay,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.gold,
                            ),
                          )
                        : const Icon(
                            Icons.today_rounded,
                            color: AppTheme.gold,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKu ? 'Pêşbirka Rojê' : 'Günün Yarışması',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isKu
                              ? 'Her roj 10 pirsên nû — îro bilîze!'
                              : 'Her gün 10 yeni soru — bugün oyna!',
                          style: TextStyle(
                            color: AppTheme.textSubColor(context),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppTheme.gold,
                    size: 34,
                  ),
                ],
              ),
            ),
          ),
          const ShimmerGlow(),
        ],
      ),
    );
  }
}
