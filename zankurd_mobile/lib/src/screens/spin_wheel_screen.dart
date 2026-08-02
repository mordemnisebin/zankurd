import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/sound_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/confetti_overlay.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
  bool _statusError = false;
  bool _statusRequestInFlight = false;
  bool _spinning = false;
  int? _wonAmount;
  String? _spinErrorMessage;
  bool _retrySpinStatus = false;
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

    // "Hareketi azalt" açıkken 3.8 saniyelik dönüş kısaltılır.
    //
    // Çark hareketin kendisi olduğu için tamamen kaldırılmaz — sonuç yine
    // görünür, yalnız uzun dönüş gider. Sağlayıcının belgesi de tam bunu
    // söylüyor: "uzun giriş/scale/bounce animasyonları kısaltılır"
    // (2026-08-02 denetimi: bu ekran tercihi hiç okumuyordu).
    _spinController = AnimationController(
      vsync: this,
      duration: ReducedMotionProvider.isReducedIn(context)
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 3800),
    );
    _rotation = const AlwaysStoppedAnimation(0);
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
    if (_statusRequestInFlight) return;
    _statusRequestInFlight = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _statusError = false;
        _spinErrorMessage = null;
      });
    }
    try {
      final can = await widget.repository.canSpinToday();
      if (!mounted) return;
      setState(() {
        _canSpin = can;
        _loading = false;
        _statusError = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'canSpinToday failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _statusError = true;
        });
      }
    } finally {
      _statusRequestInFlight = false;
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
      _spinErrorMessage = null;
    });

    const rewards = SpinWheelScreen.rewards;
    int won;
    try {
      won = await widget.repository.awardSpinCoins();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'awardSpinCoins failed');
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _spinErrorMessage = context.t(K.wheelRewardFailed);
        _retrySpinStatus = false;
      });
      return;
    }
    if (won <= 0) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _canSpin = false;
        _spinErrorMessage = context.t(K.wheelAlreadySpun);
        _retrySpinStatus = true;
      });
      return;
    }
    final winnerIndex = rewards.contains(won) ? rewards.indexOf(won) : 0;
    final segment = 2 * math.pi / rewards.length;
    // işaretçi üstte (−90°); kazanan dilimin ortası işaretçiye gelsin.
    final target =
        2 * math.pi * 5 - (winnerIndex * segment + segment / 2) - math.pi / 2;

    _rotation = Tween<double>(begin: 0, end: target).animate(
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
      appBar: AppBar(title: Text(context.t(K.wheelTitle))),
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
                  : _statusError
                  ? AppErrorState(
                      title: context.t(K.loadFailedShort),
                      message: context.t(K.wheelStatusFailed),
                      retryLabel: context.t(K.retryShort),
                      onRetry: _checkSpin,
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
                        if (_spinErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: AppErrorState(
                              title: context.t(K.loadFailedShort),
                              message: _spinErrorMessage!,
                              retryLabel: context.t(K.retryShort),
                              onRetry: _retrySpinStatus ? _checkSpin : _spin,
                            ),
                          ),
                        // ── Günlük hak durumu (her durumda görünür) ──
                        _buildSpinStatusChip(context, ku),
                        const SizedBox(height: AppSpacing.sm),
                        // ── Spin button ──
                        _buildSpinButton(context, ku),
                        // ── Countdown ──
                        if (!_canSpin && !_spinning) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildCountdownCard(context, ku, isDark),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          context.t(K.wheelRewardNote),
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
                  if (!mounted) return;
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
          // Sarı/gold gradyan üzerinde beyaz metin kontrastı zayıftı;
          // her iki temada da koyu yeşil zemin + gold vurgu kullanılır.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brandDeep, Color(0xFF17503A)],
          ),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: isDark ? 0.30 : 0.45),
          ),
          boxShadow: AppTheme.glowShadow(AppTheme.gold, intensity: 0.15),
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
                AppIcons.dice,
                color: AppTheme.gold.withValues(alpha: 0.95),
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.t(K.wheelOncePerDay),
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              context.t(K.wheelSub),
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
          // Pointer (top arrow) — belirgin merkez gösterge üçgeni
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(44, 40),
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
    return Semantics(
      liveRegion: true,
      label: context.t(K.wheelWonAmount, {'amount': '$amount'}),
      child: ScaleTransition(
        scale: _prizeScale,
        child: FadeTransition(
          opacity: _prizeOpacity,
          child: AppPanel(
            gradient: AppTheme.goldGradient,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              children: [
                // Altın gradyan üzerinde beyaz metin okunmuyordu (~1.9:1);
                // ödülün duyurulduğu an görünmez haldeydi (2026-07-22 UX
                // denetimi). Altın zeminde doğru ön plan koyu mürekkeptir.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bg.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    AppIcons.champagneGlasses,
                    color: AppTheme.bg,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(K.congrats),
                        style: const TextStyle(
                          color: AppTheme.bg,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.t(K.wheelWonPlus, {'amount': '$amount'}),
                        style: TextStyle(
                          color: AppTheme.bg.withValues(alpha: 0.88),
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
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Günlük hak durumu çipi
  // ────────────────────────────────────────────
  Widget _buildSpinStatusChip(BuildContext context, bool ku) {
    final hasRight = _canSpin;
    final label = hasRight
        ? (context.t(K.wheelReady))
        : (context.t(K.wheelUsed, {
            'time': _formatDuration(_timeUntilNextSpin),
          }));
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (hasRight ? AppTheme.correct : AppTheme.gold).withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: (hasRight ? AppTheme.correct : AppTheme.gold).withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasRight ? AppIcons.circleCheck : AppIcons.lock,
              size: 16,
              color: hasRight ? AppTheme.correct : AppTheme.gold,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSubColor(context),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
          // Düğmenin arkasındaki hâle.
          //
          // Genişliği 220 px sabitti, düğme ise satır boyunca uzuyor: hâle
          // düğmenin altından taşıp kenarlarda ayrı bir sarı şerit olarak
          // görünüyor, üstteki durum rozetinin altına giriyordu. Yoğunluk da
          // ekranın "yumuşak" dilini bozacak kadar yüksekti (2026-07-26).
          // Hâle artık düğmenin biçimini izler ve yalnız onu aydınlatır.
          if (enabled)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.30),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.18),
                        blurRadius: 40,
                        spreadRadius: 2,
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
                disabledBackgroundColor: AppTheme.surfaceHiColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                // Material yükseltisi bu boyutta sert, siyah bir halka
                // çiziyor ve düğmeyi kalın bir çerçeveyle sarılmış gibi
                // gösteriyordu; ekranın yumuşak diline aykırıydı. Kaldırma
                // hissini yukarıdaki hâle veriyor (2026-07-26).
                elevation: 0,
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
                  : Icon(enabled ? AppIcons.dice : AppIcons.lock, size: 22),
              label: Text(
                _spinning
                    ? (context.t(K.wheelSpinning))
                    : enabled
                    ? (context.t(K.wheelSpin))
                    : (context.t(K.wheelComeTomorrow)),
                style: AppTypography.bodyLarge.copyWith(
                  color: enabled
                      ? Colors.white
                      : AppTheme.textMutedColor(context),
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
              ? [AppTheme.surfaceHi.withValues(alpha: 0.9), AppTheme.surface]
              : [AppTheme.lightSurfaceHi, AppTheme.lightSurface],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.clock, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                context.t(K.wheelNextSpinIn),
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
              _countdownUnit(parts[0], context.t(K.hours), context),
              _countdownSeparator(),
              _countdownUnit(parts[1], context.t(K.minutes), context),
              _countdownSeparator(),
              _countdownUnit(parts[2], context.t(K.seconds), context),
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

  // Marka paletinin 4 tonu: yeşil / hardal / teal / koyu yeşil — eski
  // 8-renkli gökkuşağı yerine sakin, tutarlı kimlik. 8 dilim bu 4 tonu
  // dönüşümlü kullanır.
  static const _segmentColors = [
    AppTheme.brand,
    AppTheme.secondaryAccent,
    AppTheme.playCyan,
    AppTheme.playGreen,
  ];

  static const _segmentDarkColors = [
    AppTheme.brandDeep,
    AppTheme.gold,
    AppTheme.ctaTealDeep,
    AppTheme.culturalBrandBg,
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
        ..shader = gradient.createShader(
          rect,
          textDirection: TextDirection.ltr,
        );

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
      // 2026-07-22 canlı UX denetimi: çark metin düzeltmesi
      // Çark Transform.rotate ile döndürülüyor; metinleri dik tutmak için
      // her metin çiziminde counter-rotation uygulanır.
      final textAngle = startAngle + sweep / 2;
      final textRadius = innerRadius * 0.66;
      final textCenterX = center.dx + math.cos(textAngle) * textRadius;
      final textCenterY = center.dy + math.sin(textAngle) * textRadius;

      // Sarı/altın dilimlerde beyaz metin kontrastı zayıftı (~1.9:1);
      // koyu metin ile AA uyumlu (~4.5:1) kontrast sağlanır.
      final isGoldSegment = (i % _segmentColors.length) == 1;
      final textColor = isGoldSegment ? AppTheme.bg : Colors.white;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rewards[i]}',
          style: TextStyle(
            // `CustomPainter` içindeki metin temayı görmez: aile yazılmazsa
            // sistem varsayılanına düşer ve çarkın rakamları uygulamanın
            // geri kalanından başka bir yazı tipiyle çizilir (2026-07-26).
            fontFamily: AppTypography.fontFamily,
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            // Gölge beyaz rakamı koyu dilimden ayırmak için; koyu rakamın
            // altında ise kendi rengini bulandırıp okunurluğu düşürüyordu
            // — altın dilimlerdeki 20 ve 25 lekeli görünüyordu
            // (2026-07-27). Gölge de yazı rengi gibi zemine bağlı.
            shadows: [
              Shadow(
                color: (textColor == Colors.white ? Colors.black : Colors.white)
                    .withValues(alpha: 0.6),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textCenterX, textCenterY); // metin merkezine taşı
      canvas.rotate(-angle); // çark açısını geri al (counter-rotation)
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
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
    const ledCount = 16;
    final ledRadius = outerRadius + 6.0;

    for (var i = 0; i < ledCount; i++) {
      final currentLedAngle = i * (2 * math.pi / ledCount);
      final ledCenter = Offset(
        center.dx + math.cos(currentLedAngle) * ledRadius,
        center.dy + math.sin(currentLedAngle) * ledRadius,
      );

      final intensity = math.sin(i * (2 * math.pi / ledCount) * 2 - angle * 5);
      final isLit = intensity > 0.0;

      if (isLit) {
        // Glow halo
        final glowPaint = Paint()
          ..color = AppTheme.gold.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(ledCenter, 6.5, glowPaint);
      }

      final ledPaint = Paint()
        ..color = isLit ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.25)
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

    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppTheme.gold, AppTheme.secondaryAccent],
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );

    // White border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
