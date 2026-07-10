import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/colorful_action_card.dart';

/// Kompakt 2x2 "hemen oyna" ızgarası: 1v1 düello, günün yarışması, çark,
/// turnuva. Pirs-inspired ortak [ColorfulActionCard] ailesini kullanır:
/// 1vs1 pembe, günlük yarışma turuncu, çark yeşil, turnuva turkuaz.
class QuickPlayGrid extends StatelessWidget {
  const QuickPlayGrid({
    required this.isKu,
    required this.dailyQuizLoading,
    required this.onDuel,
    required this.onDailyQuiz,
    required this.onSpinWheel,
    required this.onTournament,
    super.key,
  });

  final bool isKu;
  final bool dailyQuizLoading;
  final VoidCallback onDuel;
  final VoidCallback onDailyQuiz;
  final VoidCallback onSpinWheel;
  final VoidCallback onTournament;

  /// Gradient'in ikinci durağı: aynı rengin hafif koyulaştırılmışı.
  static Color _deepen(Color color) =>
      Color.alphaBlend(Colors.black.withValues(alpha: 0.16), color);

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ColorfulActionCard(
        key: const ValueKey('quick-play-duel'),
        title: isKu ? 'Şerê 1vs1' : '1vs1 Düello',
        subtitle: isKu ? 'Zindî' : 'Canlı',
        icon: Icons.bolt_rounded,
        colors: [AppTheme.playPink, _deepen(AppTheme.playPink)],
        onTap: onDuel,
      ),
      ColorfulActionCard(
        key: const ValueKey('quick-play-daily'),
        title: isKu ? 'Pêşbirka Rojê' : 'Günün Yarışması',
        subtitle: isKu ? '10 pirs' : '10 soru',
        icon: Icons.today_rounded,
        colors: const [AppTheme.brandOrange, AppTheme.brandOrangeWarm],
        loading: dailyQuizLoading,
        onTap: onDailyQuiz,
      ),
      ColorfulActionCard(
        key: const ValueKey('quick-play-wheel'),
        title: isKu ? 'Çerxa Rojê' : 'Günün Çarkı',
        subtitle: '100 coin',
        icon: Icons.casino_outlined,
        colors: [AppTheme.playGreen, _deepen(AppTheme.playGreen)],
        onTap: onSpinWheel,
      ),
      ColorfulActionCard(
        key: const ValueKey('quick-play-tournament'),
        title: isKu ? 'Turnuva' : 'Turnuva Modu',
        subtitle: isKu ? 'Bot kûpa' : 'Bot kupa',
        icon: Icons.emoji_events_outlined,
        colors: [AppTheme.playCyan, _deepen(AppTheme.playCyan)],
        onTap: onTournament,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : 2;
        // Sabit bir tile yüksekliği kullanılır (aspect ratio değil): dar
        // konteynerlerde (ör. iki sütunlu masaüstü bölünmesinde ~80px
        // genişlik) aspectRatio tabanlı yükseklik hesaplaması metni
        // taşırıyordu. mainAxisExtent genişlikten bağımsız, öngörülebilir
        // bir yükseklik garanti eder.
        return GridView.builder(
          itemCount: tiles.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 112,
          ),
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }
}
