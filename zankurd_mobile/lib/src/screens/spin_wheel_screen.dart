import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/remote_availability.dart';
import '../providers/sound_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/network_error.dart';
import '../widgets/app_state.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../services/app_haptics.dart';

/// Çarkın tablet üst sınırı (R6); telefonda genişlik belirler.
const double spinWheelMaxDiameter = 440;

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

  /// W5: satın alınmış, kullanılmamış ek çevirme sayısı.
  int _extraSpins = 0;
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
          AppHaptics.selection();
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
    // Sunucudaki `can_spin_today` / `award_spin_coins` `public.app_today()`
    // (`Europe/Istanbul`, kalıcı UTC+3) ile gün sınırı çizer.
    final istanbul = DateTime.now().toUtc().add(const Duration(hours: 3));
    final nextMidnight = DateTime.utc(
      istanbul.year,
      istanbul.month,
      istanbul.day + 1,
    );
    if (mounted) {
      setState(() {
        _timeUntilNextSpin = nextMidnight.difference(istanbul);
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
      var extra = 0;
      try {
        extra = await widget.repository.unusedExtraSpins();
      } catch (_) {
        extra = 0;
      }
      if (!mounted) return;
      setState(() {
        _extraSpins = extra;
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
    AppHaptics.medium();
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
    // Ödül isteği sürerken ekrandan çıkılmış olabilir: kapanmış denetleyiciye
    // dokunmak hata fırlatırdı (2026-10-28 gece kod denetimi). Ödül
    // sunucuda yazıldı; çark yeniden açılınca bakiye güncel görünür.
    if (!mounted) return;
    final winnerIndex = rewards.contains(won) ? rewards.indexOf(won) : 0;
    final segment = 2 * math.pi / rewards.length;
    // işaretçi üstte (−90°); kazanan dilimin ortası işaretçiye gelsin.
    final target =
        2 * math.pi * 5 - (winnerIndex * segment + segment / 2) - math.pi / 2;

    _rotation = Tween<double>(
      begin: 0,
      end: target,
    ).chain(CurveTween(curve: Curves.easeOutQuart)).animate(_spinController);
    _spinController.reset();
    _lastPlayedSegment = -1;
    await _spinController.forward();
    AppHaptics.medium();

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

  /// Ödül ve geri sayım kartlarının yaklaşık yükseklikleri (çarkı küçültmek
  /// için; ölçü değil, ayırma payı).
  static const double _prizeCardHeight = 84;
  static const double _countdownCardHeight = 140;

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
    Widget? stageBody;
    Widget body = const SliverToBoxAdapter(child: SizedBox.shrink());
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
      // 2026-10-28 tur 3 T1: üst çubuğun altındaki BÜTÜN alan koyu oyun
      // sahnesidir (soru/sonuç gibi); çark beyaz sayfada yüzen koyu kart
      // değildi. Çark sahne yüksekliğinin ~%58'inde, dikey ortada; alan
      // kısa/yazı büyükse içerik kayar. "Çevir" sahnenin dibinde sabit.
      //
      // 2026-10-29 (X9): ödül + geri sayım kartı görününce içerik alt
      // perdeye varıyor, "Saat/Dakika/Saniye" etiketleri düğmenin altında
      // kalıyordu. (1) Kaydırma alanına alt boşluk eklendi; (2) bu iki kart
      // görünürken çark kartların yüksekliği kadar küçülür ki ilk bakışta
      // hepsi sığsın.
      final showCountdown =
          !_canSpin &&
          !_spinning &&
          !RemoteAvailability.socialLockedWatch(context);
      final extrasHeight =
          (_wonAmount != null ? _prizeCardHeight + SahneSpace.cardGap : 0.0) +
          (showCountdown ? _countdownCardHeight + SahneSpace.cardGap : 0.0);
      stageBody = LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            0,
            SahneSpace.page,
            SahneSpace.x4,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Center(
              child: Column(
                key: const ValueKey('spin-balanced-body'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWheelStage(
                    context,
                    ku,
                    math.max(0.0, box.maxHeight - extrasHeight),
                  ),
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
                  if (showCountdown) ...[
                    const SizedBox(height: SahneSpace.cardGap),
                    _buildCountdownCard(context, ku),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final showDock = !_loading && !_statusError;
    return Stack(
      children: [
        SahnePushedPage(
          role: SahneRole.race,
          title: context.t(K.wheelTitle),
          backLabel: context.t(K.back),
          slivers: [body],
          stageBody: stageBody,
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
  //  Çark sahnesi: başlık, tek satır, çark
  // ────────────────────────────────────────────
  //
  // 2026-09-29 doğallık (K10): ekran aynı şeyi dört kez söylüyordu —
  // "Her gün bir kez çevir." başlığı, "Jeton kazan ve serini sürdür" alt
  // satırı, "Bugünkü hakkın hazır" çipi ve kartın altında "Ödül doğrudan
  // jetonlarına eklenir." notu. Kalan: başlık + ödülün nereye gittiğini
  // söyleyen tek satır + alttaki düğme. Hakkın durumu düğmenin kendisidir
  // ("Çevir" / "Yarın tekrar gel."); hak bitince geri sayım kartı çıkar.
  // "Serini sürdür" sözü ayrıca bir karşılık taşımıyordu: çark ekranı
  // seriye dokunmaz, yalnız jeton verir.
  Widget _buildWheelStage(BuildContext context, bool ku, double areaHeight) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            _extraSpins > 0
                ? '${context.t(K.wheelFreeDaily)} '
                      '${context.t(K.wheelExtraSpins, {'n': '$_extraSpins'})}'
                : context.t(K.wheelFreeDaily),
            key: const ValueKey('spin-daily-line'),
            textAlign: TextAlign.center,
            style: SahneType.headline.copyWith(color: t.tx),
          ),
        ),
        // Y8 (2026-10-29 tur 6): çarktaki sayıların ne olduğu yazmıyordu
        // (jeton mu, XP mi): tek satır "Jeton kazan".
        const SizedBox(height: SahneSpace.x1),
        Text(
          context.t(K.earnCoins),
          key: const ValueKey('spin-prize-kind'),
          textAlign: TextAlign.center,
          style: SahneType.caption.copyWith(color: t.tx2),
        ),
        const SizedBox(height: SahneSpace.x4),
        _buildWheelSection(areaHeight),
      ],
    );
  }

  // ────────────────────────────────────────────
  //  Wheel section
  // ────────────────────────────────────────────
  Widget _buildWheelSection(double areaHeight) {
    // `SliverFillRemaining` iç boyut sorar: LayoutBuilder kullanılamaz, çap
    // ekran ölçüsünden türer.
    return Builder(
      builder: (context) {
        final t = SahneTokens.of(context);
        // R6 (2026-10-28 tur 2): çark sayfa kenar boşlukları ve kart payı
        // düşülmüş genişliği doldurur (tablet üst sınırı 440; kısa/yatay
        // ekranda yüksekliğe de bağlı); eskiden 300'de kalıyordu.
        final screen = MediaQuery.sizeOf(context);
        // T1: çark sahne yüksekliğinin ~%58'i; telefonda genişlik (kenar
        // boşlukları düşülmüş) sınırlar, böylece ≥%70 genişlik (R6) korunur.
        final size = math.max(
          0.0,
          math.min(
            math.min(screen.width - 2 * SahneSpace.page, spinWheelMaxDiameter),
            math.max(240.0, areaHeight * 0.62),
          ),
        );
        return Center(
          child: SizedBox.square(
            key: const ValueKey('spin-wheel-dial'),
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
                // Ortada ZK göbeği: yuvarlak, Halka 3 altın. 2026-09-29
                // doğallık: göbek elmastı; elmas yalnız soru ilerlemesi ve
                // ders sayacı anlamını taşır (K5). Çarkın göbeği çarkın
                // kendisi gibi yuvarlaktır.
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: t.s1,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: t.gold,
                        width: SahneRing.r3,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: math.max(60.0, size * 0.2),
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
                    size: Size(
                      32 * math.max(1.0, size / 300),
                      40 * math.max(1.0, size / 300),
                    ),
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
  //  Spin button (alt perde, tek birincil)
  // ────────────────────────────────────────────
  Widget _buildSpinButton(BuildContext context, bool ku) {
    final enabled = _canSpin && !_spinning;
    // W16 (2026-10-28 tur 5): sunucuya ulaşılamıyorken çark çevrilemez ama
    // sebep "bugün hakkını kullandın" DEĞİL; "Yarın tekrar gel" yalan olurdu.
    final offline = RemoteAvailability.socialLockedWatch(context);
    // Pasif hâl opaklık değil: Perde + üçüncül metin (bileşenin işi).
    return SahneButton.primary(
      label: _spinning
          ? (context.t(K.wheelSpinning))
          : enabled
          ? (context.t(K.wheelSpin))
          : offline
          ? context.t(K.internetRequired)
          : (context.t(K.wheelComeTomorrow)),
      icon: enabled || _spinning ? AppIcons.ferrisWheel : AppIcons.lock,
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
