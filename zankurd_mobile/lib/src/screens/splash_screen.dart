import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_logo.dart';
import '../widgets/branded_loader.dart';
import '../widgets/sahne/sahne.dart';
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
    // Marka ölçeği easeOutBack ile zıplar; geçiş de 450 ms solar. Tercih
    // açıkken ikisi de atlanır — aksi hâlde kullanıcının gördüğü ilk
    // ekran ayarı yok saymış olur.
    final reduce = ReducedMotionProvider.isReducedIn(context);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: reduce
            ? Duration.zero
            : const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) =>
            reduce ? child : FadeTransition(opacity: animation, child: child),
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
    if (ReducedMotionProvider.isReducedIn(context)) {
      _controller.value = 1;
    }
    final t = SahneTokens.of(context);
    return Scaffold(
      // Gradient katmanı üstte; zemin yine de tema rengi olsun ki
      // geçiş anında beyaz flaş olmasın.
      backgroundColor: AppTheme.bgOf(context),
      body: Stack(
        children: [
          // Zemin uygulamanın kendi zemini.
          //
          // Eskiden sabit koyu yeşil bir gradyandı ve açılışta üç renk arka
          // arkaya geliyordu: sistem açılış ekranı → bu ekran koyu yeşil →
          // uygulama. İki saniyede iki kez renk atlıyordu (2026-07-28).
          // Varsayılan tema gece olduğu için açılış da gece zemini üstünde
          // durur; gündüz temasını seçmiş kullanıcıda zemin gündüzdür.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.backgroundGradient(context),
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
                    Icon(icon, size: 24, color: t.tx3),
                ],
              ),
            ),
          ),
          // 2026-09-29 Şahnê: marka anı — logo işareti plakada (gecede
          // Kulis, gündüzde Perde + kenar; dağlar koyu zeminde kaybolmaz),
          // altında "ZanKurd" ve Zêr yükleyici. Süs daireleri ve koyu temada
          // tam logoyu açan renk süzgeci kalktı: plaka kontrastı kendisi
          // taşır.
          //
          // Logo kullanılabilir alana göre küçülür; dar/alçak ekranda
          // (ör. 375x812 web, yatay mod) sütun taşmaz (2026-07-24).
          //
          // 2026-09-29 doğallık (K3): logo ~%40 küçüldü (128 → 76). Ekranı
          // dolduran logo plakası marka anını değil logoyu öne çıkarıyordu;
          // büyük boyda kenar kırıntısı da seçiliyordu. Adı "ZanKurd"
          // yazısı taşır.
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = [
                      76.0,
                      constraints.maxWidth * 0.24,
                      (constraints.maxHeight - 160) / 1.3 * 0.6,
                    ].reduce((a, b) => a < b ? a : b).clamp(58.0, 76.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogo(width: width, onBrandSurface: true),
                        const SizedBox(height: SahneSpace.x5),
                        Text(
                          'ZanKurd',
                          style: SahneType.title.copyWith(color: t.tx),
                        ),
                        const SizedBox(height: SahneSpace.x6),
                        const BrandedLoader(size: 24, strokeWidth: 2.5),
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
