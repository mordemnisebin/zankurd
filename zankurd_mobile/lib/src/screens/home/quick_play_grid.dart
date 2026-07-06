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
        index: 0,
      ),
      _QuickPlayTile(
        gradientColors: const [AppTheme.gold, Color(0xFFFF8F00)],
        icon: Icons.today_rounded,
        title: isKu ? 'Pêşbirka Rojê' : 'Günün Yarışması',
        subtitle: isKu ? '10 pirs' : '10 soru',
        loading: dailyQuizLoading,
        onTap: onDailyQuiz,
        index: 1,
      ),
      _QuickPlayTile(
        gradientColors: const [AppTheme.violet, AppTheme.secondaryAccent],
        icon: Icons.casino_outlined,
        title: isKu ? 'Çerxa Rojê' : 'Günün Çarkı',
        subtitle: '100 coin',
        onTap: onSpinWheel,
        index: 2,
      ),
      _QuickPlayTile(
        gradientColors: AppTheme.tournamentGradient,
        icon: Icons.emoji_events_outlined,
        title: isKu ? 'Turnuva' : 'Turnuva Modu',
        subtitle: isKu ? 'Kûpa' : 'Kupa',
        onTap: onTournament,
        index: 3,
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
            mainAxisExtent: 112,
          ),
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }
}

class _QuickPlayTile extends StatefulWidget {
  const _QuickPlayTile({
    required this.gradientColors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.index,
    this.loading = false,
  });

  final List<Color> gradientColors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;
  final int index;

  @override
  State<_QuickPlayTile> createState() => _QuickPlayTileState();
}

class _QuickPlayTileState extends State<_QuickPlayTile>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(
        widget.index * 0.15,
        0.6 + widget.index * 0.1,
        curve: Curves.easeOut,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Interval(
        widget.index * 0.15,
        0.6 + widget.index * 0.1,
        curve: Curves.easeOut,
      ),
    ));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double shadowHeight = 4.0;

    final shadowColor = widget.gradientColors.last.withValues(alpha: 0.95);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTapDown: widget.loading
              ? null
              : (_) => setState(() => _isPressed = true),
          onTapUp: widget.loading
              ? null
              : (_) {
                  setState(() => _isPressed = false);
                  widget.onTap();
                },
          onTapCancel: widget.loading
              ? null
              : () => setState(() => _isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(
              top: _isPressed ? shadowHeight : 0,
              bottom: _isPressed ? 0 : shadowHeight,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                if (!_isPressed)
                  BoxShadow(
                    color: shadowColor,
                    offset: const Offset(0, shadowHeight),
                    blurRadius: 0,
                  ),
                BoxShadow(
                  color: widget.gradientColors.first.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    right: -14,
                    bottom: -16,
                    child: Icon(
                      widget.icon,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: widget.loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(widget.icon,
                                  color: Colors.white, size: 18),
                        ),
                        const Spacer(),
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
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
