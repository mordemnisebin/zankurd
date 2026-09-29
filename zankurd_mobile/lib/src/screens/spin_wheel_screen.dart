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
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/network_error.dart';
import '../widgets/app_state.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  static const rewards = [10, 25, 50, 15, 75, 20, 100, 30];

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with TickerProviderStateMixin, RouteAware {
  ModalRoute<dynamic>? _route;

  late final AnimationController _spinController;
  late Animation<double> _rotation;
  bool _canSpin = false;
  bool _loading = true;
  bool _statusError = false;
  bool _statusOffline = false;
  bool _statusRequestInFlight = false;
  bool _spinning = false;
  int? _wonAmount;
  String? _spinErrorMessage;
  bool _spinErrorOffline = false;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<dynamic>(context);
    if (identical(route, _route)) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  // Mağazada ekstra çark satın alma (`spin_wheel_extra`) bu ekranı
  // kapatmadan gerçekleşebilir: örn. bu ekran üstüne mağaza push edilip
  // satın alma sonrası buraya geri dönülür. `_canSpin` yalnız
  // `initState`teki tek seferlik kontrolden geliyordu; ekran hâlâ
  // mount'lu (dispose olmadığı için initState tekrar çalışmıyor) kalınca
  // ekstra hak satın alınsa bile buton "yarın gel" olarak kilitli
  // kalıyordu — kullanıcının ekranı tamamen kapatıp yeniden açması
  // gerekiyordu. `RouteAware.didPopNext` bu ekran yeniden görünür
  // olduğunda çağrılır; durumu sunucudan (extra hak dahil) tazeler
  // (2026-08-14 denetimi).
  @override
  void didPopNext() {
    _checkSpin();
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
        _statusOffline = false;
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
          _statusOffline = isLikelyOfflineError(error);
        });
      }
    } finally {
      _statusRequestInFlight = false;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
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
      _spinErrorOffline = false;
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
        _spinErrorOffline = isLikelyOfflineError(error);
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

    // Prize-reveal scale animasyonu. Hareketi azalt açıkken ödül kartı
    // sıçramadan, doğrudan yerinde görünür.
    if (sahneMotionReduced(context)) {
      _prizeAnimController.value = 1;
    } else {
      _prizeAnimController.reset();
      await _prizeAnimController.forward();
    }

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
    final t = SahneTokens.of(context);

    // 2026-09-29 Şahnê: B iskeleti. Çark bir ödül sahnesidir: Zêr rolünde
    // sahne kartı (iki temada da gece) içinde durur; "Çevir!" alt perdede
    // ekranın TEK birincil eylemidir. Dilimler palet rollerinden gelir
    // (Zêr, Zimrût, Boyax, Ray) — Agir yalnız eylemin rengidir, dilim
    // dolgusu olmaz. Eski yeşil gradyan başlık kartı, altın hâleler ve
    // bulanık gölgeler kalktı.
    final Widget body;
    if (_loading) {
      body = SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: t.goldTx)),
      );
    } else if (_statusError) {
      body = SliverFillRemaining(
        child: _statusOffline
            ? AppOfflineState(
                title: context.t(K.wheelOfflineTitle),
                message: context.t(K.wheelOfflineBody),
                retryLabel: context.t(K.retryShort),
                onRetry: _checkSpin,
              )
            : AppErrorState(
                title: context.t(K.loadFailedShort),
                message: context.t(K.wheelStatusFailed),
                retryLabel: context.t(K.retryShort),
                onRetry: _checkSpin,
              ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWheelStage(context, ku),
              // ── Ödül ──
              if (_wonAmount != null) ...[
                const SizedBox(height: SahneSpace.cardGap),
                _buildPrizeReveal(context, ku, _wonAmount!),
              ],
              if (_spinErrorMessage != null) ...[
                const SizedBox(height: SahneSpace.cardGap),
                // Alt perdedeki "Çevir!" ekranın birincil eylemi; buradaki
                // yeniden deneme ikincildir (iki Agir düğme olmaz).
                _spinErrorOffline
                    ? AppOfflineState(
                        title: context.t(K.wheelOfflineTitle),
                        message: context.t(K.wheelOfflineBody),
                        retryLabel: context.t(K.retryShort),
                        primaryAction: false,
                        onRetry: _retrySpinStatus ? _checkSpin : _spin,
                      )
                    : AppErrorState(
                        title: context.t(K.loadFailedShort),
                        message: _spinErrorMessage!,
                        retryLabel: context.t(K.retryShort),
                        primaryAction: false,
                        onRetry: _retrySpinStatus ? _checkSpin : _spin,
                      ),
              ],
              // ── Geri sayım ──
              if (!_canSpin && !_spinning) ...[
                const SizedBox(height: SahneSpace.cardGap),
                _buildCountdownCard(context, ku),
              ],
              const SizedBox(height: SahneSpace.x4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SahneGlyph(SahneGlyphKind.coin, size: 16),
                  const SizedBox(width: SahneSpace.x2),
                  Flexible(
                    child: Text(
                      context.t(K.wheelRewardNote),
                      textAlign: TextAlign.center,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final showDock = !_loading && !_statusError;
    return Stack(
      children: [
        SahnePushedPage(
          title: context.t(K.wheelTitle),
          backLabel: context.t(K.back),
          slivers: [body],
          bottom: showDock ? _buildSpinButton(context, ku) : null,
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
    );
  }

  // ────────────────────────────────────────────
  //  Çark sahnesi: başlık, çark, günlük hak durumu
  // ────────────────────────────────────────────
  Widget _buildWheelStage(BuildContext context, bool ku) {
    return SahneStageCard(
      role: SahneRole.gold,
      child: Builder(
        builder: (context) {
          // Sahne kartının içi gece belirteçleridir.
          final t = SahneTokens.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.t(K.wheelOncePerDay),
                  textAlign: TextAlign.center,
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
              ),
              const SizedBox(height: SahneSpace.x1),
              Text(
                context.t(K.wheelSub),
                textAlign: TextAlign.center,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x4),
              _buildWheelSection(),
              const SizedBox(height: SahneSpace.x4),
              Center(child: _buildSpinStatusChip(context, ku)),
            ],
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Wheel section
  // ────────────────────────────────────────────
  Widget _buildWheelSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final t = SahneTokens.of(context);
        final size = math.min(constraints.maxWidth, 300.0);
        return Center(
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Çark
                AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _rotation.value,
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: _WheelPainter(
                          rewards: SpinWheelScreen.rewards,
                          angle: _rotation.value,
                          tokens: t,
                        ),
                      ),
                    );
                  },
                ),
                // Ortada ZK amblemi: elmas, Halka 3 altın.
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: t.s1,
                    shape: SahneShape.diamond(
                      68,
                      side: BorderSide(
                        color: t.gold,
                        width: SahneRing.r3,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 68,
                    child: Center(
                      child: Text(
                        'ZK',
                        style: SahneType.button.copyWith(
                          color: t.gold,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                // İşaretçi (üstte) — dilimin ortasını gösteren altın elmas uç.
                Positioned(
                  top: 0,
                  child: CustomPaint(
                    size: const Size(32, 40),
                    painter: _PointerPainter(
                      fill: t.gold,
                      edge: t.goldDeep,
                      rim: t.bg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────
  //  Prize reveal (scale-in animation)
  // ────────────────────────────────────────────
  Widget _buildPrizeReveal(BuildContext context, bool ku, int amount) {
    final t = SahneTokens.of(context);
    return Semantics(
      liveRegion: true,
      label: context.t(K.wheelWonAmount, {'amount': '$amount'}),
      child: ScaleTransition(
        scale: _prizeScale,
        child: FadeTransition(
          opacity: _prizeOpacity,
          // Ödül kartı: Zêr tonu yüzey + Halka 1 altın kaş; jeton glifi
          // ödülün türünü şekille söyler.
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: t.goldTint,
              shape: SahneShape.withSide(SahneShape.l, t.gold),
            ),
            child: Padding(
              padding: const EdgeInsets.all(SahneSpace.x4),
              child: Row(
                children: [
                  const SahneGlyph(SahneGlyphKind.coin, size: 40),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(K.congrats),
                          style: SahneType.headline.copyWith(color: t.tx),
                        ),
                        Text(
                          context.t(K.wheelWonPlus, {'amount': '$amount'}),
                          style: SahneType.bodyStrong.copyWith(color: t.goldTx),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final t = SahneTokens.of(context);
    final hasRight = _canSpin;
    final label = hasRight
        ? (context.t(K.wheelReady))
        : (context.t(K.wheelUsed, {
            'time': _formatDuration(_timeUntilNextSpin),
          }));
    // Durum yalnız renkle verilmez: ✓ (hak var) ya da kilit (hak bitti).
    final (bg, fg, icon) = hasRight
        ? (t.okTint, t.okTx, AppIcons.circleCheck)
        : (t.goldTint, t.goldTx, AppIcons.lock);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: SahneShape.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
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
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SahneType.captionStrong.copyWith(color: fg),
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
  //  Spin button (alt perde, tek birincil)
  // ────────────────────────────────────────────
  Widget _buildSpinButton(BuildContext context, bool ku) {
    final enabled = _canSpin && !_spinning;
    // Pasif hâl opaklık değil: Perde + üçüncül metin (bileşenin işi).
    return SahneButton.primary(
      label: _spinning
          ? (context.t(K.wheelSpinning))
          : enabled
          ? (context.t(K.wheelSpin))
          : (context.t(K.wheelComeTomorrow)),
      icon: enabled || _spinning ? AppIcons.dice : AppIcons.lock,
      arrow: false,
      expand: true,
      onPressed: enabled ? _spin : null,
    );
  }

  // ────────────────────────────────────────────
  //  Countdown card
  // ────────────────────────────────────────────
  Widget _buildCountdownCard(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    final formatted = _formatDuration(_timeUntilNextSpin);
    final parts = formatted.split(':');

    return SahneSurfaceCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.clock, color: t.goldTx, size: 20),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: Text(
                  context.t(K.wheelNextSpinIn),
                  style: SahneType.captionStrong.copyWith(color: t.tx2),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _countdownUnit(parts[0], context.t(K.hours), context),
                _countdownSeparator(context),
                _countdownUnit(parts[1], context.t(K.minutes), context),
                _countdownSeparator(context),
                _countdownUnit(parts[2], context.t(K.seconds), context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownUnit(String value, String label, BuildContext context) {
    final t = SahneTokens.of(context);
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
            child: SizedBox(
              width: 60,
              height: 48,
              child: Center(
                child: Text(
                  value,
                  style: SahneType.headline.copyWith(
                    color: t.tx,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            label,
            maxLines: 1,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ],
      ),
    );
  }

  Widget _countdownSeparator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x6),
      child: Text(
        ':',
        style: SahneType.headline.copyWith(
          color: SahneTokens.of(context).goldTx,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Wheel segment painter
// ═══════════════════════════════════════════════
/// Çarkın ressamı.
///
/// 2026-09-29 Şahnê: dilimler dört rol renginden dönüşümlü — Zêr, Zimrût,
/// Boyax, Ray (`s3`). Agir yok: turuncu yalnız birincil eylemin rengidir.
/// Rakam rengi dilime göre karşıtlıkla seçilir ([sahneOnFill]); rakamın
/// altında gölge yok. Dış kasnak Kulis (`s2`), üstünde 16 altın ışık (yanan
/// Zêr, sönen koyu altın) — bulanık hâle (`MaskFilter`) yok.
class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.rewards,
    required this.angle,
    required this.tokens,
  });

  final List<int> rewards;
  final double angle;
  final SahneTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    const rimWidth = 16.0;
    final innerRadius = outerRadius - rimWidth;
    final segment = 2 * math.pi / rewards.length;
    final segmentColors = [t.gold, t.learn, t.race, t.s3];

    // Dış kasnak.
    canvas.drawCircle(center, outerRadius, Paint()..color = t.s2);

    for (var i = 0; i < rewards.length; i++) {
      final startAngle = i * segment;
      final fill = segmentColors[i % segmentColors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        segment,
        true,
        Paint()..color = fill,
      );

      // Dilimler arası ince ayırıcı (zemin tonu).
      final sepPaint = Paint()
        ..color = t.bg.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(startAngle) * innerRadius,
          center.dy + math.sin(startAngle) * innerRadius,
        ),
        sepPaint,
      );

      // Ödül rakamı. Çark `Transform.rotate` ile dönüyor; rakamlar dik
      // kalsın diye her çizimde karşı döndürme uygulanır (2026-07-22).
      final textAngle = startAngle + segment / 2;
      final textRadius = innerRadius * 0.68;
      final textCenter = Offset(
        center.dx + math.cos(textAngle) * textRadius,
        center.dy + math.sin(textAngle) * textRadius,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rewards[i]}',
          // `CustomPainter` içindeki metin temayı görmez: aile ve boyut
          // belirteçten açıkça verilir (2026-07-26).
          style: SahneType.headline.copyWith(
            fontFamily: SahneType.display,
            color: sahneOnFill(fill),
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(textCenter.dx, textCenter.dy);
      canvas.rotate(-angle);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // İç kenar: dilimleri kasnaktan ayıran ince zemin çizgisi.
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = t.bg,
    );

    // ── Kasnak ışıkları ──
    const ledCount = 16;
    final ledRadius = outerRadius - rimWidth / 2;
    for (var i = 0; i < ledCount; i++) {
      final a = i * (2 * math.pi / ledCount);
      final ledCenter = Offset(
        center.dx + math.cos(a) * ledRadius,
        center.dy + math.sin(a) * ledRadius,
      );
      final isLit = math.sin(a * 2 - angle * 5) > 0.0;
      canvas.drawCircle(
        ledCenter,
        3,
        Paint()..color = isLit ? t.gold : t.goldDeep.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      angle != oldDelegate.angle || tokens != oldDelegate.tokens;
}

// ═══════════════════════════════════════════════
//  Pointer painter
// ═══════════════════════════════════════════════
/// İşaretçi: aşağı bakan altın uç (koyu altın kontur, zemin tonu dış
/// çizgi). Gölge yok.
class _PointerPainter extends CustomPainter {
  const _PointerPainter({
    required this.fill,
    required this.edge,
    required this.rim,
  });

  final Color fill;
  final Color edge;
  final Color rim;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width - 2, size.height * 0.35)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(2, size.height * 0.35)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      edge != oldDelegate.edge ||
      rim != oldDelegate.rim;
}
