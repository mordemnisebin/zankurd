import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../providers/reduced_motion_provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/test_environment.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Üst üste doğru cevap serisinin görsel kademesi.
/// Eşikler spec'ten: ×3 bronz (turuncu), ×5 gümüş (mor), ×10 altın.
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
class ComboBadge extends StatelessWidget {
  const ComboBadge({required this.streak, required this.isKu, super.key});

  final int streak;
  final bool isKu;

  static const _tierColors = {
    ComboTier.bronze: Color(0xFFFF8F00),
    ComboTier.silver: Color(0xFF7C3AED),
    ComboTier.gold: Color(0xFFFFC107),
  };

  @override
  Widget build(BuildContext context) {
    final tier = comboTierFor(streak);
    return AnimatedSwitcher(
      duration: _motionOff(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: tier == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey('combo-$streak'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _tierColors[tier]!,
                    _tierColors[tier]!.withValues(alpha: 0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: _tierColors[tier]!.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.fire, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '×$streak ${Tr.forKu(K.seri, isKu)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Son saniyelerde ekran kenarlarında beliren kırmızı vinyet.
/// [animation]: quiz'in geri sayan timer controller'ı (1.0→0.0).
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
          Colors.transparent,
          AppTheme.wrong.withValues(alpha: 0.22 * strength),
        ],
        stops: const [0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter oldDelegate) =>
      oldDelegate.strength != strength;
}

/// Yanlış cevapta tam ekran çok kısa kırmızı flaş.
/// [trigger] her arttığında bir kez oynar.
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
        final opacity = (t < 0.5 ? t : 1 - t) * 0.30;
        return Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: AppTheme.wrong.withValues(alpha: opacity)),
          ),
        );
      },
    );
  }
}

/// Doğru cevapta kazanılan puanın yukarı süzülen "+N" göstergesi.
/// [trigger] her arttığında [points] değeriyle bir kez oynar.
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
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
