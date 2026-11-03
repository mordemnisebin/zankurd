import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/reduced_motion_provider.dart';
import '../utils/error_reporter.dart';
import '../widgets/launch_frame.dart';
import '../widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Uygulama açılışında gösterilen, büyük ve belirgin ZanKurd logolu ekran.
///
/// Yerel açılış ekranıyla ve `BootHost` karesiyle AYNI görüntüyü ([LaunchFrame])
/// tutarak gerçek hazırlığı (tercih deposu, ikon fontu) bekler, sonra [next]'e
/// geçer. İkinci bir marka karesi çizmez.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.next,
    this.duration = Duration.zero,
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
  /// Artık pencere süreye değil HAZIR OLMAYA bağlı: [duration] alt sınır, [readiness] ise gerçek iş. Hangisi geç biterse o belirler.
  final Duration duration;

  /// Bir sonraki ekranın ihtiyaç duyduğu hazırlık. Tamamlanmadan geçilmez.
  /// Verilmezse yalnız [duration] beklenir (eski davranış).
  final Future<void>? readiness;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Uygulama teması değil PLATFORM parlaklığı: yerel açılış ekranı tema
    // tercihini bilemez; koyu sistemde açık temaya sıçrama olmasın.
    final platform = MediaQuery.platformBrightnessOf(context);
    // İKİNCİ bir marka karesi YOK: yerel açılış ekranı → BootHost →
    // bu ekran aynı kareyi (düz zemin + aynı logo, aynı boyut/konum) çizer;
    // yalnız gerçek hazırlık (tercih deposu, ikon fontu) arkada biter.
    // Eskiden burada ölçekleyen/solan, farklı boyutlu logo + "ZanKurd" +
    // yükleyici vardı: yerel ekrandan sonra ikinci bir sıçramaydı.
    return Scaffold(
      backgroundColor: LaunchFrame.backgroundFor(platform),
      body: Stack(
        children: [
          Positioned.fill(child: LaunchFrame(brightness: platform)),
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
        ],
      ),
    );
  }
}
