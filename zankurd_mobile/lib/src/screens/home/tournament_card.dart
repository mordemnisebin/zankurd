import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/shimmer_glow.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({required this.isKu, required this.onOpen, super.key});

  final bool isKu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      glass: true,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          InkWell(
            onTap: onOpen,
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
                    child: const Icon(
                      Icons.emoji_events_outlined,
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
                          isKu ? 'Turnuva' : 'Turnuva Modu',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isKu
                              ? 'Botan eledar bike û kûpayê qezenc bike!'
                              : 'Bot rakipleri ele, kupayı kaldır!',
                          style: TextStyle(
                            color: AppTheme.textSubColor(context),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMutedColor(context),
                    size: 30,
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
