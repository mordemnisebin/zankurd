import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
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
    this.duration = const Duration(milliseconds: 600),
    this.readiness,
    super.key,
  });

  final Widget next;

  /// Markanın görünmesi için gereken EN AZ süre.
  ///
  /// 2026-07-31'e kadar 1800 ms'ti ve bu bir yükleme penceresi değil, saf
  /// gecikmeydi: `runApp` bütün başlatma zincirinden SONRA çağrıldığı için
  /// bu ekran göründüğünde iş çoktan bitmiş oluyordu. Üstüne 450 ms geçiş
  /// biniyor, ardından AppShell iki tam ekran spinner daha çiziyordu
  /// (SharedPreferences, sonra `getProfileName()` ağ çağrısı). Kullanıcı
  /// dört ayrı bekleme yüzeyi görüyordu (2026-07-31 denetimi).
  ///
  /// Artık pencere süreye değil HAZIR OLMAYA bağlı: 600 ms marka için
  /// alt sınır, [readiness] ise gerçek iş. Hangisi geç biterse o belirler.
  final Duration duration;

  /// Bir sonraki ekranın ihtiyaç duyduğu hazırlık. Tamamlanmadan geçilmez.
  /// Verilmezse yalnız [duration] beklenir (eski davranış).
  final Future<void>? readiness;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  Timer? _minimumTimer;
  bool _minimumElapsed = false;
  bool _ready = false;
  bool _navigated = false;

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
    // Marka penceresi ile gerçek hazırlık AYRI ayrı beklenir; hangisi geç
    // biterse geçişi o tetikler.
    //
    // `Future.delayed` yerine iptal edilebilir bir `Timer`: ekran erken
    // sökülürse zamanlayıcı da ölmeli. Aksi hâlde widget testleri
    // "pending timer" ile düşer ve gerçek uygulamada da sökülmüş bir
    // ağaca `pushReplacement` denenirdi.
    _minimumTimer = Timer(widget.duration, () {
      _minimumElapsed = true;
      _goNextIfReady();
    });

    final readiness = widget.readiness;
    if (readiness == null) {
      _ready = true;
    } else {
      unawaited(
        readiness
            .catchError((Object error, StackTrace stack) {
              // Açılışı bir hataya kilitlemek, geç açılmaktan kötüdür.
              ErrorReporter.record(error, stack, reason: 'splash readiness');
            })
            .whenComplete(() {
              _ready = true;
              _goNextIfReady();
            }),
      );
    }
  }

  void _goNextIfReady() {
    if (!_minimumElapsed || !_ready || _navigated) return;
    _navigated = true;
    _goNext();
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
    _minimumTimer?.cancel();
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
          // Zemin uygulamanın kendi zemini.
          //
          // Eskiden sabit koyu yeşil bir gradyandı ve açılışta üç renk arka
          // arkaya geliyordu: sistem açılış ekranı krem (#F7F4EE) →
          // bu ekran koyu yeşil → uygulama yine krem. İki saniyede iki kez
          // renk atlıyordu (2026-07-28).
          //
          // Masaüstünde ayrıca kötü duruyordu: geniş ekranda içerik 540 pt'ye
          // sınırlanıyor ve dışı yüzey rengiyle doluyor, yani koyu yeşil panel
          // krem bir zeminin ortasında yüzen bir dikdörtgen gibi görünüyordu.
          // Zemin uygulamanınkiyle aynı olunca çerçeve tamamen kayboluyor.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.backgroundGradient(context),
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
                // Süs halkaları: koyu zemine göre beyaz alfaydı, açık
                // temada görünmez oluyordu. Marka yeşilinin tonu her iki
                // temada da hafif bir derinlik verir.
                color: AppTheme.culturalBrandBg.withValues(alpha: 0.06),
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
                color: AppTheme.brand.withValues(alpha: 0.07),
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
