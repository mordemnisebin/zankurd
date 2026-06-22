import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/confetti_overlay.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  static const rewards = [10, 25, 50, 15, 75, 20, 100, 30];

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _rotation;
  bool _canSpin = false;
  bool _loading = true;
  bool _spinning = false;
  int? _wonAmount;
  int _lastPlayedSegment = -1;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _rotation = AlwaysStoppedAnimation(0);
    _controller.addListener(() {
      if (_controller.isAnimating) {
        final angle = _rotation.value;
        final segmentAngle = 2 * math.pi / SpinWheelScreen.rewards.length;
        final currentSegment = (angle / segmentAngle).floor();
        if (currentSegment != _lastPlayedSegment) {
          _lastPlayedSegment = currentSegment;
          HapticFeedback.selectionClick();
        }
      }
    });
    _checkSpin();
  }

  Future<void> _checkSpin() async {
    bool can = false;
    try {
      can = await widget.repository.canSpinToday();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'canSpinToday failed');
    }
    if (mounted) {
      setState(() {
        _canSpin = can;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || !_canSpin) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _spinning = true;
      _wonAmount = null;
    });

    final rewards = SpinWheelScreen.rewards;
    int won;
    try {
      won = await widget.repository.awardSpinCoins();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'awardSpinCoins failed');
      if (!mounted) return;
      setState(() {
        _spinning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.s('Xelat nehat dayîn.', 'Ödül verilemedi.')),
        ),
      );
      return;
    }
    if (won <= 0) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _canSpin = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Îro jixwe zivirandî.', 'Bugün zaten çevirdin.'),
          ),
        ),
      );
      return;
    }
    final winnerIndex = rewards.contains(won) ? rewards.indexOf(won) : 0;
    final segment = 2 * math.pi / rewards.length;
    // İşaretçi üstte (−90°); kazanan dilimin ortası işaretçiye gelsin.
    final target =
        2 * math.pi * 5 - (winnerIndex * segment + segment / 2) - math.pi / 2;

    _rotation = Tween<double>(
      begin: 0,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _controller.reset();
    _lastPlayedSegment = -1;
    await _controller.forward();
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _spinning = false;
        _canSpin = false;
        _wonAmount = won;
        _showConfetti = true;
      });
      try {
        context.read<SoundProvider>().playWin();
        context.read<SoundProvider>().playCoin();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Çerxa Rojê' : 'Günün Çarkı')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      children: [
                        Text(
                          ku
                              ? 'Her roj carekê bizivirîne, coin qezenc bike!'
                              : 'Her gün bir kez çevir, coin kazan!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSubColor(context),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 320,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _controller,
                                builder: (context, _) {
                                  return Transform.rotate(
                                    angle: _rotation.value,
                                    child: CustomPaint(
                                      size: const Size(300, 300),
                                      painter: _WheelPainter(
                                        rewards: SpinWheelScreen.rewards,
                                        angle: _rotation.value,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Orta göbek
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.accentGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      offset: const Offset(0, 6),
                                      blurRadius: 8,
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      offset: const Offset(0, -3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'ZK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              // Üst işaretçi
                              Positioned(
                                top: 0,
                                child: CustomPaint(
                                  size: const Size(30, 26),
                                  painter: _PointerPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_wonAmount != null) ...[
                          AppPanel(
                            gradient: AppTheme.goldGradient,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.celebration_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    ku
                                        ? 'Pîroz be! +$_wonAmount coin qezenc kir!'
                                        : 'Tebrikler! +$_wonAmount coin kazandın!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: (_canSpin && !_spinning) ? _spin : null,
                            icon: _spinning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.casino_outlined),
                            label: Text(
                              _spinning
                                  ? (ku ? 'Dizivire...' : 'Dönüyor...')
                                  : _canSpin
                                  ? (ku ? 'Bizivirîne!' : 'Çevir!')
                                  : (ku ? 'Sibê dîsa were!' : 'Yarın tekrar gel!'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          ku
                              ? 'Xelat rasterast li hejmara coinên te tê zêdekirin.'
                              : 'Ödül doğrudan coin bakiyene eklenir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
            if (_wonAmount != null && _showConfetti)
              ConfettiOverlay(
                onFinished: () {
                  setState(() {
                    _showConfetti = false;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.rewards, required this.angle});

  final List<int> rewards;
  final double angle;

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFFE94560),
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFFBD1E3B),
    Color(0xFF5B21B6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12; // LED'ler için çarkı hafifçe küçülttük
    final segment = 2 * math.pi / rewards.length;

    for (var i = 0; i < rewards.length; i++) {
      final paint = Paint()..color = _colors[i % _colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * segment,
        segment,
        true,
        paint,
      );

      // Dilim metni
      final textAngle = i * segment + segment / 2;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rewards[i]}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final textOffset = Offset(
        center.dx + math.cos(textAngle) * radius * 0.68 - textPainter.width / 2,
        center.dy + math.sin(textAngle) * radius * 0.68 - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }

    // Dış halka
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // Dönen LED Işıkları (Chasing Lights)
    final ledCount = 16;
    final ledRadius = radius + 6.0;
    final timeFactor = DateTime.now().millisecondsSinceEpoch / 200.0;

    for (var i = 0; i < ledCount; i++) {
      final currentLedAngle = i * (2 * math.pi / ledCount);
      final ledCenter = Offset(
        center.dx + math.cos(currentLedAngle) * ledRadius,
        center.dy + math.sin(currentLedAngle) * ledRadius,
      );

      // Sinüs dalgası ile kovalayan ışık yoğunluğu
      final intensity = math.sin(i * (2 * math.pi / ledCount) * 2 - angle * 4 + timeFactor);
      final isLit = intensity > 0.1;

      final ledPaint = Paint()
        ..color = isLit ? const Color(0xFFFFD700) : const Color(0x33FFD700)
        ..style = PaintingStyle.fill;

      if (isLit) {
        // Parlayan LED'in arkasına glow (parlama) efekti
        final glowPaint = Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(ledCenter, 6, glowPaint);
      }

      canvas.drawCircle(ledCenter, 3.5, ledPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => true;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height + 3)
      ..close();
    
    // Gölge çizimi
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    // Gövde
    canvas.drawPath(path, Paint()..color = AppTheme.gold);
    
    // Kenarlık konturu
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
