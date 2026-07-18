import 'dart:async';
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
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late Animation<double> _rotation;
  bool _canSpin = false;
  bool _loading = true;
  bool _spinning = false;
  int? _wonAmount;
  int _lastPlayedSegment = -1;
  bool _showConfetti = false;
  Timer? _countdownTimer;
  Duration _timeUntilNextSpin = Duration.zero;

  // ---------- Prize-reveal animation ----------
  late final AnimationController _prizeAnimController;
  late Animation<double> _prizeScale;
  late Animation<double> _prizeOpacity;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _rotation = AlwaysStoppedAnimation(0);
    _spinController.addListener(() {
      if (_spinController.isAnimating) {
        final angle = _rotation.value;
        final segmentAngle = 2 * math.pi / SpinWheelScreen.rewards.length;
        final currentSegment = (angle / segmentAngle).floor();
        if (currentSegment != _lastPlayedSegment) {
          _lastPlayedSegment = currentSegment;
          HapticFeedback.selectionClick();
        }
      }
    });

    _prizeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _prizeScale = CurvedAnimation(
      parent: _prizeAnimController,
      curve: Curves.elasticOut,
    );
    _prizeOpacity = CurvedAnimation(
      parent: _prizeAnimController,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );

    _checkSpin();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc();
    final nextMidnight = DateTime.utc(now.year, now.month, now.day + 1);
    if (mounted) {
      setState(() {
        _timeUntilNextSpin = nextMidnight.difference(now);
      });
    }
  }

  Future<void> _checkSpin() async {
    bool can = false;
    try {
      can = await widget.repository.canSpinToday();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'canSpinToday failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.s(
                'Rewşa çerxê nehat kontrolkirin.',
                'Çark durumu kontrol edilemedi.',
              ),
            ),
          ),
        );
      }
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
    _spinController.dispose();
    _prizeAnimController.dispose();
    _countdownTimer?.cancel();
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
    // işaretçi üstte (−90°); kazanan dilimin ortası işaretçiye gelsin.
    final target =
        2 * math.pi * 5 - (winnerIndex * segment + segment / 2) - math.pi / 2;

    _rotation = Tween<double>(
      begin: 0,
      end: target,
    ).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutQuart),
    );
    _spinController.reset();
    _lastPlayedSegment = -1;
    await _spinController.forward();
    HapticFeedback.mediumImpact();

    // Çark animasyonunun tam oturması için kısa nefes molası
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _spinning = false;
      _canSpin = false;
      _wonAmount = won;
      _showConfetti = true;
    });

    // Prize-reveal scale animasyonu
    _prizeAnimController.reset();
    await _prizeAnimController.forward();

    // Ödül kartı tamamen açıldıktan sonra sesi çal
    if (!mounted) return;
    try {
      context.read<SoundProvider>().playWin();
      context.read<SoundProvider>().playCoin();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'spin result sound failed');
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGradientStart,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.xs,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      children: [
                        // ── Header card ──
                        _buildHeaderCard(context, ku, isDark),
                        const SizedBox(height: AppSpacing.lg),
                        // ── Wheel ──
                        _buildWheelSection(),
                        const SizedBox(height: AppSpacing.lg),
                        // ── Prize reveal ──
                        if (_wonAmount != null)
                          _buildPrizeReveal(context, ku, _wonAmount!),
                        // ── Spin button ──
                        _buildSpinButton(context, ku),
                        // ── Countdown ──
                        if (!_canSpin && !_spinning) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildCountdownCard(context, ku, isDark),
                        ],
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

  // ────────────────────────────────────────────
  //  Header card
  // ────────────────────────────────────────────
  Widget _buildHeaderCard(BuildContext context, bool ku, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg + 4,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppTheme.secondaryAccent, AppTheme.bgDeep]
                : [
                    AppTheme.secondaryAccent.withValues(alpha: 0.7),
                    AppTheme.violet.withValues(alpha: 0.6),
                  ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: AppTheme.glowShadow(
            AppTheme.gold,
            intensity: 0.15,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.casino_outlined,
                color: AppTheme.gold.withValues(alpha: 0.95),
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ku ? 'Her roj carekê bizivirîne!' : 'Her gün bir kez çevir!',
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              ku
                  ? 'Coin qezenc bike û seriyê xwe bidomîne'
                  : 'Coin kazan ve serini sürdür',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Wheel section
  // ────────────────────────────────────────────
  Widget _buildWheelSection() {
    return SizedBox(
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Positioned.fill(
            child: Center(
              child: Container(
                width: 316,
                height: 316,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.18),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Wheel
          AnimatedBuilder(
            animation: _spinController,
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
          // Center hub
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  offset: const Offset(0, 6),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: AppTheme.primaryGradientStart.withValues(alpha: 0.45),
                  offset: const Offset(0, 0),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'ZK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          // Pointer (top arrow)
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(32, 28),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Prize reveal (scale-in animation)
  // ────────────────────────────────────────────
  Widget _buildPrizeReveal(BuildContext context, bool ku, int amount) {
    return ScaleTransition(
      scale: _prizeScale,
      child: FadeTransition(
        opacity: _prizeOpacity,
        child: AppPanel(
          gradient: AppTheme.goldGradient,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 18,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ku ? 'Pîroz be!' : 'Tebrikler!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ku
                          ? '+$amount coin qezenc kir!'
                          : '+$amount coin kazandın!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Spin button
  // ────────────────────────────────────────────
  Widget _buildSpinButton(BuildContext context, bool ku) {
    final enabled = _canSpin && !_spinning;

    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // Glow halo behind button
          if (enabled)
            Positioned.fill(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  width: 220,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.55),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.35),
                        blurRadius: 48,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: enabled ? _spin : null,
              style: FilledButton.styleFrom(
                backgroundColor: enabled ? AppTheme.accent : null,
                disabledBackgroundColor:
                    AppTheme.surfaceHiColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                elevation: enabled ? 4 : 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              icon: _spinning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      enabled
                          ? Icons.casino_outlined
                          : Icons.lock_outlined,
                      size: 22,
                    ),
              label: Text(
                _spinning
                    ? (ku ? 'Dizivire...' : 'Dönüyor...')
                    : enabled
                        ? (ku ? 'Bizivirîne!' : 'Çevir!')
                        : (ku ? 'Sibê dîsa were!' : 'Yarın tekrar gel!'),
                style: AppTypography.bodyLarge.copyWith(
                  color: enabled ? Colors.white : AppTheme.textMutedColor(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Countdown card
  // ────────────────────────────────────────────
  Widget _buildCountdownCard(BuildContext context, bool ku, bool isDark) {
    final formatted = _formatDuration(_timeUntilNextSpin);
    final parts = formatted.split(':');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: AppTheme.premiumCard(
        context,
        glowColor: AppTheme.secondaryAccent,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.surfaceHi.withValues(alpha: 0.9),
                  AppTheme.surface,
                ]
              : [
                  AppTheme.lightSurfaceHi,
                  AppTheme.lightSurface,
                ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_rounded, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                ku ? 'Dizivirîna nû di:' : 'Yeni çevirme hakkı:',
                style: TextStyle(
                  color: AppTheme.textSubColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _countdownUnit(parts[0], ku ? 'Saet' : 'Saat', context),
              _countdownSeparator(),
              _countdownUnit(parts[1], ku ? 'Deqîqe' : 'Dakika', context),
              _countdownSeparator(),
              _countdownUnit(parts[2], ku ? 'Saniye' : 'Saniye', context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownUnit(String value, String label, BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.25),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
                fontSize: 20,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: AppTheme.gold,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Wheel segment painter
// ═══════════════════════════════════════════════
class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.rewards, required this.angle});

  final List<int> rewards;
  final double angle;

  // Marka ailesinden: kategori kartlarında zaten kullanılan
  // AppTheme.categoryGradients ile aynı 8 renk — eski "gökkuşağı" oyuncak
  // paleti (coral/sky/hot-pink) yerine tutarlı bir kimlik.
  static const _segmentColors = [
    AppTheme.gold,
    AppTheme.correct,
    Color(0xFFC67A5C), // terracotta
    Color(0xFF2E7D7E), // teal
    AppTheme.wrong,
    Color(0xFF6B3A7A), // erik moru
    Color(0xFFD4A84B), // amber
    Color(0xFF3D6B4F), // orman yeşili
  ];

  static const _segmentDarkColors = [
    Color(0xFFB8872E),
    AppTheme.brandGreenDeep,
    Color(0xFF9B4A2E),
    Color(0xFF1A5C5C),
    Color(0xFFB6402F),
    Color(0xFF452250),
    Color(0xFFB8860B),
    Color(0xFF1E4D2E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - 14; // space for border ring
    final segment = 2 * math.pi / rewards.length;

    for (var i = 0; i < rewards.length; i++) {
      final startAngle = i * segment;
      final sweep = segment;

      // Segment fill with gradient
      final rect = Rect.fromCircle(center: center, radius: innerRadius);
      final lightColor = _segmentColors[i % _segmentColors.length];
      final darkColor = _segmentDarkColors[i % _segmentDarkColors.length];

      final gradient = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [lightColor, darkColor, lightColor, darkColor],
        stops: const [0.0, 0.48, 0.52, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect, textDirection: TextDirection.ltr);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        sweep,
        true,
        paint,
      );

      // Thin separator line between segments
      final sepPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final sepX = center.dx + math.cos(startAngle) * innerRadius;
      final sepY = center.dy + math.sin(startAngle) * innerRadius;
      canvas.drawLine(center, Offset(sepX, sepY), sepPaint);

      // Reward text
      final textAngle = startAngle + sweep / 2;
      final textRadius = innerRadius * 0.66;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rewards[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            shadows: [
              Shadow(
                color: Color(0x99000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final textOffset = Offset(
        center.dx +
            math.cos(textAngle) * textRadius -
            textPainter.width / 2,
        center.dy +
            math.sin(textAngle) * textRadius -
            textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }

    // Outer border ring
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // ── LED chasing lights ──
    final ledCount = 16;
    final ledRadius = outerRadius + 6.0;

    for (var i = 0; i < ledCount; i++) {
      final currentLedAngle = i * (2 * math.pi / ledCount);
      final ledCenter = Offset(
        center.dx + math.cos(currentLedAngle) * ledRadius,
        center.dy + math.sin(currentLedAngle) * ledRadius,
      );

      final intensity =
          math.sin(i * (2 * math.pi / ledCount) * 2 - angle * 5);
      final isLit = intensity > 0.0;

      if (isLit) {
        // Glow halo
        final glowPaint = Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.5)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(ledCenter, 6.5, glowPaint);
      }

      final ledPaint = Paint()
        ..color = isLit ? const Color(0xFFFFD700) : const Color(0x44FFD700)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(ledCenter, 3.5, ledPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      angle != oldDelegate.angle;
}

// ═══════════════════════════════════════════════
//  Pointer / arrow painter
// ═══════════════════════════════════════════════
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Shadow
    final shadowPath = Path()
      ..moveTo(4, 0)
      ..lineTo(size.width - 4, 0)
      ..lineTo(size.width / 2, size.height + 4)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Body with gradient
    final path = Path()
      ..moveTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppTheme.gold, const Color(0xFFD4A017)],
    );
    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // White border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
