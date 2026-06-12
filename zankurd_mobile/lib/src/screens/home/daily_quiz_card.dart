import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';

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
      gradient: AppTheme.goldGradient,
      padding: EdgeInsets.zero,
      child: InkWell(
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.today_rounded,
                        color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isKu
                          ? 'Her roj 10 pirsên nû — îro bilîze!'
                          : 'Her gün 10 yeni soru — bugün oyna!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
