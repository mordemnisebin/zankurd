import 'package:flutter/widgets.dart';

import '../../utils/question_timer_resume.dart';

/// Soru geri sayım sayacının durumunu ve yaşam döngüsünü yöneten kontrolcü.
///
/// `quiz_screen.dart` içindeki sayaç karmaşasını azaltır:
/// - Animasyon kontrolcüsü ve süre yönetimi
/// - Duraklatma (pause), sürdürme (resume) ve senkronizasyon (sync)
/// - Uygulama arka plana geçtiğinde güvenli duraklatma ve geri dönüş kontrolü
/// - Süre dolduğunda [onTimeout] tetiklemesi
class QuizTimerController {
  QuizTimerController({
    required TickerProvider vsync,
    required Duration duration,
    required this.onTimeout,
    this.isUntimed = false,
  }) {
    _controller = AnimationController(
      vsync: vsync,
      duration: duration,
      value: 1.0,
    );

    _controller.addStatusListener(_handleStatusChange);
  }

  late final AnimationController _controller;
  final VoidCallback onTimeout;
  final bool isUntimed;

  bool _pausedByLifecycle = false;

  AnimationController get animationController => _controller;
  Animation<double> get animation => _controller;

  double get value => _controller.value;
  bool get isAnimating => _controller.isAnimating;
  bool get isPausedByLifecycle => _pausedByLifecycle;

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !isUntimed) {
      onTimeout();
    }
  }

  /// Sayacı belirli bir kesirle (varsayılan 1.0) başlatır ve geriye sayar.
  void start({double initialFraction = 1.0}) {
    _pausedByLifecycle = false;
    _controller.stop();
    _controller.value = initialFraction.clamp(0.0, 1.0);
    if (!isUntimed && _controller.value > 0) {
      _controller.reverse();
    }
  }

  /// Sayacı duraklatır.
  void pause() {
    _controller.stop();
  }

  /// Sayacı kaldığı yerden geriye saymaya devam ettirir.
  void resume() {
    if (!isUntimed && _controller.value > 0 && !_controller.isAnimating) {
      _controller.reverse();
    }
  }

  /// Sunucu veya ağ senkronizasyonundan gelen kesirle günceller.
  void sync(double fraction) {
    _controller.stop();
    _controller.value = fraction.clamp(0.0, 1.0);
    if (!isUntimed && _controller.value > 0) {
      _controller.reverse();
    }
  }

  /// Uygulama arka plana giderken sayacı güvenle duraklatır.
  void handleLifecyclePause() {
    if (_controller.isAnimating) {
      _pausedByLifecycle = true;
      _controller.stop();
    }
  }

  /// Uygulama ön plana dönerken sayacın sürdürülüp sürdürülmeyeceğini
  /// [shouldResumeQuestionTimer] kuralına göre belirler.
  bool handleLifecycleResume() {
    final shouldResume = shouldResumeQuestionTimer(
      pausedByLifecycle: _pausedByLifecycle,
      isAnimating: _controller.isAnimating,
      timerValue: _controller.value,
    );
    _pausedByLifecycle = false;
    if (shouldResume && !isUntimed) {
      _controller.reverse();
      return true;
    }
    return false;
  }

  void dispose() {
    _controller.stop();
    _controller.removeStatusListener(_handleStatusChange);
    _controller.dispose();
  }
}
