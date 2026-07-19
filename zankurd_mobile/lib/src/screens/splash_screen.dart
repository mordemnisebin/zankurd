import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Uygulama açılışında gösterilen, büyük ve belirgin ZanKurd logolu ekran.
///
/// Native (sistem) splash'i Android 12+ üzerinde logoyu küçük tuttuğu için,
/// bu ekran uygulama içinde tam kontrol sağlayarak logoyu büyük gösterir,
/// kısa bir animasyondan sonra [next] ekranına yumuşak geçiş yapar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.next,
    this.duration = const Duration(milliseconds: 1800),
    super.key,
  });

  final Widget next;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  // İkon "tofu" (boş kutu) sorunu: MaterialIcons web fontu ilk ikon
  // rasterize edilene kadar yüklenmez; geç yüklenirse ana ekranda ikonlar
  // boş kutu görünüyordu. Splash'te gizli bir ikon seti çizerek fontu
  // peşinen yüklüyoruz (precache).
  static const _precacheIcons = [
    Icons.home_rounded,
    Icons.leaderboard_rounded,
    Icons.person_rounded,
    Icons.settings_rounded,
    Icons.play_arrow_rounded,
    Icons.star_rounded,
    Icons.check_rounded,
    Icons.close_rounded,
    Icons.timer_outlined,
    Icons.emoji_events_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _timer = Timer(widget.duration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgOf(context),
      body: Stack(
        children: [
          // Gizli ikon katmanı — font precache (görünmez, layout etkilemez).
          Positioned(
            left: -1000,
            top: -1000,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (final icon in _precacheIcons)
                    Icon(
                      icon,
                      size: 24,
                      color: AppTheme.textMutedColor(context),
                    ),
                ],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(width: 280),
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.brandGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
