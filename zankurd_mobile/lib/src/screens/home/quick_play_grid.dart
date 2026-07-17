import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/colorful_action_card.dart';

/// Tam-genişlik "hemen oyna" kart listesi: 1v1 düello, günün yarışması,
/// çark, turnuva. Kategorî'nin kompakt satır diliyle tutarlı [ColorfulActionCard]
/// ailesini kullanır — her mod kendi kimlik rengini ikon çipinde taşır.
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

    // Pirs-tarzı: tam-genişlik, tek-eylem kartlar dikey listede — küçük
    // grid yerine her mod tek satırda, taranması kolay ve büyük bir
    // dokunma alanı taşır. Sabit yükseklik yerine içeriğe göre doğal
    // boyutlanır (dar/geniş konteynerlerde taşma olmaz).
    final content = Column(
      children: [
        for (var i = 0; i < tiles.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == tiles.length - 1 ? 0 : AppSpacing.sm,
            ),
            child: SizedBox(width: double.infinity, child: tiles[i]),
          ),
      ],
    );

    // Preview cards and compact embedded surfaces may be shorter than the
    // complete mode list. Let those surfaces scroll instead of overflowing;
    // the full play hub keeps its natural height inside its parent ListView.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight && constraints.maxHeight < 500) {
          return SingleChildScrollView(child: content);
        }
        return content;
      },
    );
  }
}
