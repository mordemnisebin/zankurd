import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
    AppIcons.house,
    AppIcons.chartColumn,
    AppIcons.user,
    AppIcons.gear,
    AppIcons.play,
    AppIcons.star,
    AppIcons.check,
    AppIcons.xmark,
    AppIcons.stopwatch,
    AppIcons.trophy,
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
      // Gradient katmanı üstte; zemin yine de tema rengi olsun ki
      // geçiş anında beyaz flaş olmasın.
      backgroundColor: AppTheme.bgOf(context),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF173C2D),
                    Color(0xFF1E4A38),
                    Color(0xFF0E1411),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: 80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brand.withValues(alpha: 0.08),
              ),
            ),
          ),
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
          // Logo sabit 280px idi; dar/alçak ekranlarda (ör. 375x812 web,
          // yatay mod) sütun 17px taşıyordu. Artık kullanılabilir alana
          // göre küçülür ve taşma imkânsız hâle gelir.
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxLogo = constraints.maxWidth * 0.72;
                    final byHeight = constraints.maxHeight - 90;
                    final width = [
                      280.0,
                      maxLogo,
                      byHeight,
                    ].reduce((a, b) => a < b ? a : b).clamp(96.0, 280.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogo(width: width),
                        const SizedBox(height: 28),
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.brand,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
