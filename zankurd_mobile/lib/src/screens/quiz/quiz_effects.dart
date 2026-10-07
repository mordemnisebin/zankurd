import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../providers/reduced_motion_provider.dart';

import '../../utils/test_environment.dart';
import '../../widgets/sahne/sahne.dart';

/// Üst üste doğru cevap serisinin görsel kademesi.
/// Eşikler spec'ten: ×3 bronz, ×5 gümüş, ×10 altın. Kademe Şahnê'de
/// renkle değil glifle ayrışır (bkz. [ComboBadge]).
enum ComboTier { bronze, silver, gold }

ComboTier? comboTierFor(int streak) {
  if (streak >= 10) return ComboTier.gold;
  if (streak >= 5) return ComboTier.silver;
  if (streak >= 3) return ComboTier.bronze;
  return null;
}

/// [_kVignetteThreshold] — vinyetin başladığı süre oranı eşiği.
/// Bu değer UX denetiminden onaylanmıştır; değiştirilirse visual test güncellenmeli.
const double _kVignetteThreshold = 1 / 3;

/// Kalan süre oranından (1.0 = dolu, 0.0 = bitti) kırmızı kenar vinyetinin
/// gücünü üretir. Son üçte birde 0→1 doğrusal tırmanır; öncesinde 0.
double vignetteStrengthFor(double remainingFraction) {
  final clamped = remainingFraction.clamp(0.0, 1.0);
  if (clamped >= _kVignetteThreshold) return 0.0;
  return (_kVignetteThreshold - clamped) / _kVignetteThreshold;
}

/// Yanlış cevapta şıkkı yatay sarsar. [trigger] her arttığında bir kez
/// oynar; trigger > 0 ile İLK kurulduğunda da oynar (yanlış-şık sarmalama
/// senaryosu: widget yanlış anlaşıldığı anda ağaca girer).
/// Hareket azaltılıyor mu? Efektler ÇALIŞMA ANINDA buna bakar.
///
/// 2026-07-31'e kadar bu efektlerin süreleri yalnız
/// `isFlutterTestEnvironment` ile sıfırlanıyordu: yani animasyonlar
/// sadece TEST KOŞUCUSUNDA kapanıyor, gerçek kullanıcının "hareketi
/// azalt" tercihi hiçbirini etkilemiyordu. Yanlış cevaptaki tam genişlikte
/// kırmızı parlama ve sarsıntı, hareket duyarlılığı olan kullanıcı için
/// tam da kapatılması gereken şeydi.
/// YALNIZ kullanıcı/sistem tercihi. `isFlutterTestEnvironment` BİLEREK
/// dahil değil: o bayrak yalnız ilk kurulumdaki otomatik oynatmayı
/// susturmak içindi, tetiklenen efektleri değil. İkisini birleştirmek
/// `quiz_effects_test`i kırdı — test sarsıntının GERÇEKTEN oynadığını
/// ölçüyor.
bool _motionOff(BuildContext context) =>
    ReducedMotionProvider.isReducedIn(context);

class ShakeWrapper extends StatefulWidget {
  const ShakeWrapper({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  State<ShakeWrapper> createState() => _ShakeWrapperState();
}

class _ShakeWrapperState extends State<ShakeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.trigger > 0 &&
          !isFlutterTestEnvironment &&
          !_motionOff(context)) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShakeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (_motionOff(context)) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sönümlenen sinüs: 3 tam salınım, gittikçe küçülen genlik.
        final t = _controller.value;
        final offset = math.sin(t * math.pi * 6) * (1 - t) * 8;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// "×N Seri!" rozeti. [comboTierFor] null dönerse hiçbir şey çizmez.
///
/// Şahnê: seri bir ÖDÜLdür, rengi Zêr (altın ton zemin + koyu altın
/// metin), M pahlı çip. Kademe renkle değil GLİFLE ayrışır: ×3 alev,
/// ×5 şimşek, ×10 taç. Eski turuncu/mor/altın dolgular palet dışıydı ve
/// bulanık gölge taşıyordu; ikisi de kalktı.
class ComboBadge extends StatelessWidget {
  const ComboBadge({required this.streak, required this.isKu, super.key});

  final int streak;
  final bool isKu;

  static SahneGlyphKind glyphFor(ComboTier tier) => switch (tier) {
    ComboTier.bronze => SahneGlyphKind.flame,
    ComboTier.silver => SahneGlyphKind.bolt,
    ComboTier.gold => SahneGlyphKind.crown,
  };

  @override
  Widget build(BuildContext context) {
    final tier = comboTierFor(streak);
    final t = SahneTokens.of(context);
    return AnimatedSwitcher(
      duration: _motionOff(context) ? Duration.zero : SahneMotion.diamondPop,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: tier == null
          ? const SizedBox.shrink()
          : DecoratedBox(
              key: ValueKey('combo-$streak'),
              decoration: ShapeDecoration(
                color: t.goldTint,
                shape: SahneShape.m,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: SahneSpace.x2,
                  end: SahneSpace.x3,
                  top: SahneSpace.x1,
                  bottom: SahneSpace.x1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SahneGlyph(glyphFor(tier), size: 20),
                    const SizedBox(width: SahneSpace.x2),
                    Flexible(
                      child: Text(
                        '×$streak ${Tr.forKu(K.seri, isKu)}',
                        style: SahneType.captionStrong.copyWith(
                          color: t.goldTx,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Son saniyelerde ekran kenarlarında beliren gerilim vinyeti.
/// [animation]: quiz'in geri sayan timer controller'ı (1.0→0.0).
///
/// Şahnê: gerilimin rengi Boyax'tır (sayaç halesiyle aynı aile, bkz.
/// `SahneStageColors.haloRace`); durum kırmızısı (Şaş) değil — süre
/// azalıyor diye cevap "yanlış" değildir. Radyal gradyan, bulanıklık yok.
class CriticalVignette extends StatelessWidget {
  const CriticalVignette({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final strength = vignetteStrengthFor(animation.value);
        if (strength <= 0) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _VignettePainter(strength: strength)),
          ),
        );
      },
    );
  }
}

class _VignettePainter extends CustomPainter {
  _VignettePainter({required this.strength});

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [
          SahneStageColors.haloRace.withValues(alpha: 0),
          SahneStageColors.haloRace.withValues(
            alpha: SahneStageColors.haloRace.a * strength,
          ),
        ],
        stops: const [0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter oldDelegate) =>
      oldDelegate.strength != strength;
}

/// Yanlış cevapta tam ekran çok kısa Şaş flaşı.
/// [trigger] her arttığında bir kez oynar. Şahnê'de flaş hafiftir (tepe
/// %16): asıl söz şıkkın Şaş dolgusu, çapraz taraması ve ✗'idir.
class WrongFlash extends StatefulWidget {
  const WrongFlash({required this.trigger, super.key});

  final int trigger;

  @override
  State<WrongFlash> createState() => _WrongFlashState();
}

class _WrongFlashState extends State<WrongFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: isFlutterTestEnvironment
        ? Duration.zero
        : const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(covariant WrongFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (_motionOff(context)) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating) return const SizedBox.shrink();
        // 0→tepe→0 üçgen opaklık eğrisi
        final t = _controller.value;
        final opacity = (t < 0.5 ? t : 1 - t) * 0.32;
        return Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: SahneTokens.of(context).errFill.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}

/// Doğru cevapta kazanılan puanın yukarı süzülen "+N" göstergesi.
/// [trigger] her arttığında [points] değeriyle bir kez oynar. Zêr, Manşet
/// 22, tablo rakamı; gölgesiz (bulanık metin gölgesi kalktı).
class ScoreFlyup extends StatefulWidget {
  const ScoreFlyup({required this.trigger, required this.points, super.key});

  final int trigger;
  final int points;

  @override
  State<ScoreFlyup> createState() => _ScoreFlyupState();
}

class _ScoreFlyupState extends State<ScoreFlyup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: isFlutterTestEnvironment
        ? Duration.zero
        : const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant ScoreFlyup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (_motionOff(context)) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating) return const SizedBox.shrink();
        final t = Curves.easeOut.transform(_controller.value);
        return IgnorePointer(
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -40 * t),
              child: Text(
                '+${widget.points}',
                style: SahneType.headline.copyWith(
                  color: SahneTokens.of(context).goldTx,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
