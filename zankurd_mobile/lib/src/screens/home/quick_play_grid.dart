import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Kompakt 2x2 "hemen oyna" ızgarası: 1v1 düello, günün yarışması, çark,
/// turnuva. Bu dört aksiyon eskiden ayrı ayrı tam-genişlik kartlardı
/// (bkz. docs/superpowers/specs/2026-07-04-auth-home-redesign-design.md);
/// burada tek bir yoğun, hâlâ renkli ve okunaklı ızgarada birleşiyor.
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

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _QuickPlayTile(
        gradientColors: AppTheme.duelGradient,
        icon: Icons.bolt_rounded,
        title: isKu ? 'Şerê 1V1' : '1V1 Düello',
        subtitle: isKu ? 'Zindî' : 'Canlı',
        onTap: onDuel,
      ),
      _QuickPlayTile(
        gradientColors: const [AppTheme.gold, Color(0xFFFF8F00)],
        icon: Icons.today_rounded,
        title: isKu ? 'Pêşbirka Rojê' : 'Günün Yarışması',
        subtitle: isKu ? '10 pirs' : '10 soru',
        loading: dailyQuizLoading,
        onTap: onDailyQuiz,
      ),
      _QuickPlayTile(
        gradientColors: const [AppTheme.violet, AppTheme.secondaryAccent],
        icon: Icons.casino_outlined,
        title: isKu ? 'Çerxa Rojê' : 'Günün Çarkı',
        subtitle: '100 coin',
        onTap: onSpinWheel,
      ),
      _QuickPlayTile(
        gradientColors: AppTheme.tournamentGradient,
        icon: Icons.emoji_events_outlined,
        title: isKu ? 'Turnuva' : 'Turnuva Modu',
        subtitle: isKu ? 'Kûpa' : 'Kupa',
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
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 108,
          ),
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }
}

class _QuickPlayTile extends StatelessWidget {
  const _QuickPlayTile({
    required this.gradientColors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final List<Color> gradientColors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            boxShadow: AppTheme.elevatedShadow(gradientColors.first),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 20),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      // Geniş ekranda ResponsiveWrapper içeriği 480px'lik
                      // sabit bir çerçeveye sıkıştırırken HomeScreen'in
                      // isWide kararı gerçek pencere genişliğine bakıyor;
                      // bu durumda ızgara çok dar bir yarı-sütuna düşüyor.
                      // 2 satıra izin vermek, o durumda "Günün Yarışması"
                      // gibi uzun başlıkların "Günün Ya..." diye
                      // kesilmesini önlüyor; sabit yükseklikte zaten
                      // yeterli boşluk var.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
