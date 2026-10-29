import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sahne/sahne_foundation.dart';

/// Maskotun pozu (VAY_KATMANI A4, 2026-10-29).
///
/// Anlam poza değil metne aittir: maskot dekoratiftir. Poz yalnız tonu
/// söyler — karşılama, rehberlik, kutlama, destek ya da (küçük boyda)
/// doğru/yanlış geri bildirimi.
enum ZanPose {
  /// El sallayan karşılama: boş durumlar, ana sayfa.
  welcome('selam', 'assets/mascot/selam.svg', 278 / 198),

  /// Düşünen rehber: öğrenme girişi, ipucu.
  guide('dusunen', 'assets/mascot/dusunen.svg', 278 / 198),

  /// Kollar havada kutlama: iyi sonuç.
  celebrate('mutlu', 'assets/mascot/mutlu.svg', 278 / 198),

  /// Cesaretlendiren üzüntü: düşük sonuç, kayıp.
  support('uzgun', 'assets/mascot/uzgun.svg', 278 / 198),

  /// Küçük (mini) doğru geri bildirimi: büyük yüz, sade atkı.
  correct('mini_dogru', 'assets/mascot/mini_dogru.svg', 212 / 188),

  /// Küçük (mini) yanlış geri bildirimi.
  wrong('mini_yanlis', 'assets/mascot/mini_yanlis.svg', 212 / 188);

  const ZanPose(this.asset, this.path, this.aspect);

  /// `assets/mascot/<asset>.svg`.
  final String asset;

  /// Genişlik / yükseklik (SVG `viewBox` oranı).
  final double aspect;

  /// Dosya yolu (tam yol: varlık kullanım bekçisi tam yolu arar).
  final String path;
}

/// ZanKurd maskotu "Zan": logodaki turuncu konuşma balonu canlanmış hâli.
///
/// SVG varlıklarını `flutter_svg` ile çizer (filtre/maske yok; yalnız
/// çokgen, elips, yol ve `clipPath`). [size] maskotun GENİŞLİĞİdir; yükseklik
/// pozun oranından gelir. Ana boy 112–136, yardımcı 64–84, mini 44–56.
///
/// Dekoratiftir: [ExcludeSemantics] — anlamı yanındaki metin taşır.
/// Giriş hareketi tek bir 360 ms zıplama + hafif el sallama; "hareketi azalt"
/// açıkken ([sahneMotionReduced]) maskot sabit çizilir.
class ZanMascot extends StatefulWidget {
  const ZanMascot({
    required this.pose,
    required this.size,
    this.animate = true,
    super.key,
  });

  final ZanPose pose;

  /// TEST yardımcısı: bütün pozların SVG'sini önceden yükler. Widget testinde
  /// varlık okuma gerçek G/Ç'dir (sahte saatte ilerlemez); `tester.runAsync`
  /// içinde çağrılırsa sonraki `pump`lar maskotu eşzamanlı çizer.
  @visibleForTesting
  static Future<void> preloadForTest() async {
    for (final p in ZanPose.values) {
      await SvgAssetLoader(p.path).loadBytes(null);
    }
  }

  /// Genişlik (mantıksal piksel).
  final double size;

  /// Giriş hareketi; `false` → sabit.
  final bool animate;

  @override
  State<ZanMascot> createState() => _ZanMascotState();
}

class _ZanMascotState extends State<ZanMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !_reduceMotion(context)) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w / widget.pose.aspect;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // Zıplama: 0 → -8 → 0 (sinüs), el sallama: ±0,05 rad sönümlü.
          final hop = -8 * math.sin(t * math.pi);
          final tilt = 0.05 * math.sin(t * 2 * math.pi) * (1 - t);
          return Transform.translate(
            offset: Offset(0, hop),
            child: Transform.rotate(
              angle: tilt,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: SizedBox(
          key: ValueKey('zan-mascot-${widget.pose.asset}'),
          width: w,
          height: h,
          child: SvgPicture.asset(
            widget.pose.path,
            width: w,
            height: h,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// "Hareketi azalt" açık mı ([sahneMotionReduced]).
bool _reduceMotion(BuildContext context) => sahneMotionReduced(context);
