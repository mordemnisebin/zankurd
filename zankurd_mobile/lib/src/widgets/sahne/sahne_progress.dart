import 'package:flutter/material.dart';

import '../../theme/sahne.dart';
import '../../utils/percent_format.dart';
import 'sahne_foundation.dart';
import 'sahne_painters.dart';

export 'sahne_painters.dart' show SahneDiamondState;

/// İlerleme izinin kenar rengi.
///
/// 2026-09-30 izgara: gündüzde iz (`s3` #D0D7EC) beyaz yüzeyde ve sayfa
/// zemininde ~1,4:1 kalıyor, BOŞ (%0) çubuk neredeyse görünmüyordu — "0/5
/// seviye" satırı ve ana ekrandaki oynanmamış konu karoları boş sayfa gibi
/// duruyordu. Gündüzde iz, ikincil metin renginden türeyen 1 px kenar alır
/// (≥ 3:1); gecede iz zaten koyu yüzeyden ayrışır, kenar şeffaf kalır.
Color sahneTrackEdge(SahneTokens t) => t.bg == SahneTokens.day.bg
    ? t.tx3.withValues(alpha: 0.75)
    : Colors.transparent;

/// İlerleme çubuğunun tonu.
enum SahneProgressTone {
  /// Öğrenme (`learnBar`): ders, konu.
  learn,

  /// Ödül (Zêr): XP, seviye.
  gold,
}

/// İlerleme çubuğu — maketteki `.sh-bar` / `.sh-prog`.
///
/// 8 px, S pah; iz Ray (`s3`; gündüzde ince bir kenarla, bkz.
/// [sahneTrackEdge]), dolgu öğrenmede `learnBar`, ödülde Zêr.
/// İsteğe bağlı sağda değer ([trailing], ör. "2/5", "200 XP"; kalın
/// açıklama, tablo rakamı). Ekran okuyucu değeri yüzde olarak duyar.
/// Değer değişimi 240 ms kayar; hareketi azaltta anında.
class SahneProgressBar extends StatelessWidget {
  const SahneProgressBar({
    super.key,
    required this.value,
    this.tone = SahneProgressTone.learn,
    this.trailing,
    this.semanticLabel,
  });

  /// 0–1.
  final double value;
  final SahneProgressTone tone;
  final String? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final v = value.clamp(0.0, 1.0);
    final fill = tone == SahneProgressTone.gold ? t.gold : t.learnBar;
    final reduceMotion = sahneMotionReduced(context);
    final bar = TweenAnimationBuilder<double>(
      tween: Tween(end: v),
      duration: reduceMotion ? Duration.zero : SahneMotion.answerReveal,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: t.s3,
            shape: SahneShape.withSide(
              SahneShape.s,
              sahneTrackEdge(t),
              width: 1,
            ),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: animated,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(color: fill, shape: SahneShape.s),
              ),
            ),
          ),
        ),
      ),
    );
    final percent = PercentFormat.ratio(v, isKu: sahneIsKu(context));
    // Büyük yazı ölçeğinde (≥ 1.5) sağdaki değer çubuğun yanında durmaz,
    // ALTINA iner (liste satırındaki rozetle aynı kural): "0/2 Seviye" gibi
    // bir değer %200'de 256 px'lik satırı 39 px taşırıyordu (Seviyeler,
    // 320 px). Çubuk 0 genişliğe inebilir ama değer metni inemez; kısaltmak
    // da yanlış bilgi olurdu, o yüzden değer kendi satırını alır.
    final stacked = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final valueText = trailing == null
        ? null
        : Text(
            trailing!,
            style: SahneType.captionStrong.copyWith(
              color: t.tx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    return Semantics(
      label: semanticLabel,
      value: trailing ?? percent,
      excludeSemantics: true,
      child: valueText == null
          ? bar
          : stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                bar,
                const SizedBox(height: SahneSpace.x1),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: valueText,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: bar),
                const SizedBox(width: SahneSpace.x3),
                Flexible(flex: 0, child: valueText),
              ],
            ),
    );
  }
}

/// 10'lu elmas dizisi — oyun sahnesinin soru ilerlemesi (maketteki
/// `.sh-dias`).
///
/// Her hücre 24 px; durum ŞEKİLLE ayrışır ([SahneDiamondState]): doğru dolu
/// + ✓, yanlış boş + ✗, bekleyen çizgi; [currentIndex] altın dış halka
/// alır. Hücre durum değiştirince 200 ms "pırlar" (1 → 1.2 → 1); hareketi
/// azaltta yalnız şekil değişir. Dar ekranda dizi sığdırılarak küçülür.
/// Ekran okuyucu tek bir özet okur ([semanticLabel], ör. "3/10: 2 doğru,
/// 1 yanlış").
class SahneDiamondRow extends StatelessWidget {
  const SahneDiamondRow({
    super.key,
    required this.states,
    required this.semanticLabel,
    this.currentIndex,
  });

  final List<SahneDiamondState> states;
  final int? currentIndex;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < states.length; i++)
              _PoppingDiamond(state: states[i], current: i == currentIndex),
          ],
        ),
      ),
    );
  }
}

class _PoppingDiamond extends StatefulWidget {
  const _PoppingDiamond({required this.state, required this.current});

  final SahneDiamondState state;
  final bool current;

  @override
  State<_PoppingDiamond> createState() => _PoppingDiamondState();
}

class _PoppingDiamondState extends State<_PoppingDiamond>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: SahneMotion.diamondPop,
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.2,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.2,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 1,
    ),
  ]);

  @override
  void didUpdateWidget(_PoppingDiamond old) {
    super.didUpdateWidget(old);
    final reduceMotion = sahneMotionReduced(context);
    if (old.state != widget.state && !reduceMotion) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ScaleTransition(
      scale: _scale.animate(_pop),
      child: SizedBox.square(
        dimension: 24,
        child: CustomPaint(
          painter: SahneDiamondPainter(
            state: widget.state,
            tokens: t,
            current: widget.current,
          ),
        ),
      ),
    );
  }
}

/// Yol düğümünün durumu.
enum SahnePathNodeState { done, inProgress, locked }

/// Öğrenme yolu düğümü — 24'lük elmas (maketteki `.sh-node`).
///
/// Bitti: dolu Rast + ✓. Sürüyor: yarısı Zimrût dolu + halka. Kilitli:
/// yalnız çizgi, içi zemin (yol çizgisi arkasından geçmez). Işıma yok.
class SahnePathNode extends StatelessWidget {
  const SahnePathNode({
    super.key,
    required this.state,
    required this.semanticLabel,
  });

  final SahnePathNodeState state;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 24,
        child: CustomPaint(
          painter: SahneDiamondPainter(
            tokens: t,
            fillPending: true,
            state: switch (state) {
              SahnePathNodeState.done => SahneDiamondState.correct,
              SahnePathNodeState.inProgress => SahneDiamondState.half,
              SahnePathNodeState.locked => SahneDiamondState.pending,
            },
          ),
        ),
      ),
    );
  }
}

/// Ders elması — "2/5" (maketteki `.sh-gauge`).
///
/// 80 px elmas; içi öğrenme tonu, iz Ray, ilerleme Zimrût metniyle TEPE
/// köşeden saat yönünde dolar (sayaçla aynı ilke). Sayı Manşet 22, tablo
/// rakamı; büyük yazı ölçeğinde elmasın içine sığdırılır.
class SahneLessonDiamond extends StatelessWidget {
  const SahneLessonDiamond({
    super.key,
    required this.done,
    required this.total,
    this.size = 80,
    this.semanticLabel,
  });

  final int done;
  final int total;
  final double size;

  /// Varsayılan: "done/total".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fraction = total <= 0 ? 0.0 : done / total;
    return Semantics(
      label: semanticLabel ?? '$done/$total',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: SahneDiamondTrackPainter(
            fill: t.learnTint,
            track: t.s3,
            trail: t.learnTx,
            fraction: fraction,
            fromTop: true,
          ),
          child: _DiamondLabel(text: '$done/$total', color: t.tx, size: size),
        ),
      ),
    );
  }
}

/// Sayaç — oyun sahnesinin ortasındaki elmas (maketteki `.sh-timer`).
///
/// 60 px elmas, zemin rengiyle dolu; 4 px iz TEPE köşeden saat yönünde
/// tükenir (`PathMetric.extractPath`). Son [hotSeconds] saniyede iz ve
/// sayı Boyax'a döner, arkada 116 px Boyax hale belirir (gradyan,
/// bulanıklık yok) ve elmas 600 ms'lik nabızla 1 → 1.06 atar; hareketi
/// azaltta yalnız renk değişir.
///
/// 2026-09-29 doğallık (K9): hale YALNIZ son saniyelerde. Eskiden sakin
/// sayaç da sürekli altın (ya da kategori ışığında) bir hale taşıyordu;
/// her an parlayan öğe gerilim anını söyleyemiyordu. [light] geriye uyum
/// için kalır; sakin sayaçta hale olmadığından artık bir şey boyamaz.
class SahneTimerDiamond extends StatefulWidget {
  const SahneTimerDiamond({
    super.key,
    required this.secondsLeft,
    required this.fraction,
    required this.semanticLabel,
    this.hotSeconds = 5,
    this.light,
  });

  /// Kategori ışığı. Geriye uyum: sakin sayaçta hale yok, eşikte hale
  /// her zaman Boyax — bu alan artık görünüşü değiştirmez.
  final Color? light;

  /// Halenin rengi: eşikte yarış halesi, değilse `null` (hale yok).
  static Color? haloColor({required bool hot, Color? light}) =>
      hot ? SahneStageColors.haloRace : null;

  final int secondsLeft;

  /// Kalan sürenin oranı (0–1).
  final double fraction;

  /// Ör. "17 saniye kaldı".
  final String semanticLabel;
  final int hotSeconds;

  /// Gerilim eşiğinde mi?
  bool get isHot => secondsLeft <= hotSeconds;

  /// İzin ve sayının rengi: normalde Zêr, eşikte Boyax metni.
  static Color trailColor(SahneTokens t, {required bool hot}) =>
      hot ? t.raceTx : t.gold;

  @override
  State<SahneTimerDiamond> createState() => _SahneTimerDiamondState();
}

class _SahneTimerDiamondState extends State<SahneTimerDiamond>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: SahneMotion.tension,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(SahneTimerDiamond oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final reduceMotion = sahneMotionReduced(context);
    final run = widget.isHot && !reduceMotion;
    if (run && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!run && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final hot = widget.isHot;
    final color = SahneTimerDiamond.trailColor(t, hot: hot);
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse),
        child: SizedBox.square(
          dimension: 60,
          child: CustomPaint(
            painter: SahneDiamondTrackPainter(
              fill: t.bg,
              track: SahneStageColors.timerTrack,
              trail: color,
              fraction: widget.fraction,
              fromTop: false,
              halo: SahneTimerDiamond.haloColor(hot: hot, light: widget.light),
            ),
            child: _DiamondLabel(
              text: '${widget.secondsLeft}',
              color: hot ? t.raceTx : t.tx,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}

/// Elmasın ortasındaki sayı: Manşet 22, tablo rakamı; elmasın iç
/// karesine (kenarın %60'ı) sığdırılır, büyük yazıda taşmaz.
class _DiamondLabel extends StatelessWidget {
  const _DiamondLabel({
    required this.text,
    required this.color,
    required this.size,
  });

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size * 0.6,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: SahneType.headline.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
