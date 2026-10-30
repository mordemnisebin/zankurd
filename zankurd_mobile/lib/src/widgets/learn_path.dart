import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_haptics.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';
import 'zan_mascot.dart';

/// Öğrenme "keşif rotası" (vay katmanı 2B, B6 — 2026-10-29).
///
/// ## Niçin
///
/// GPT-6 Astra (Duolingo kıyası, 7/10): "dersler bir öğrenme yolculuğundan
/// çok liste gibi; maskot ve ilerleme heyecanı eksik". Eski düzende etkin
/// ders yeşil bir kart, ötekiler numaralı satırlardı. Duolingo'nun yolu
/// kıvrımlı bir patikada iri, kabartmalı düğümlerdir; nerede olduğun tek
/// bakışta görünür.
///
/// ## Düzen
///
/// * [LearnUnitScene]: ünitenin başında gündüz (koyu temada gece) dağ
///   manzarası, sağda düşünen maskot (rehber), altında ünite adı, "0/5 ders"
///   ve beş parçalı ilerleme.
/// * [LearnPath]: ünitenin dersleri kıvrımlı bir yol üstünde 64'lük
///   düğümler; güncel ders 80'lik düğüm + 3 px halka. Güncel düğümün altına
///   çağıranın verdiği kart ([LearnPathStop.attachment]) bir konuşma
///   balonu gibi oturur (üstte düğüme bakan küçük uç).
///
/// Yol her satırın KENDİ boyacısıyla çizilir: satır, düğüm merkezinden
/// komşu düğümle arasındaki orta noktaya kadar yarım eğriyi çizer. Böylece
/// araya kart girse de (güncel ders) yol kesintisiz okunur ve satır
/// yükseklikleri büyük yazıda serbestçe uzar.
///
/// Dekor ekran okuyucuya görünmez; her durak tek düğme olarak okunur
/// (etiketi çağıran verir: "Sıradaki ders. Alfabe. Sonraki").
enum LearnNodeState { done, current, open, locked }

/// Yolun bir durağı.
class LearnPathStop {
  const LearnPathStop({
    required this.state,
    required this.step,
    required this.icon,
    required this.semanticLabel,
    this.title,
    this.status,
    this.onTap,
    this.attachment,
    this.after,
    this.wrap,
  });

  final LearnNodeState state;

  /// Yoldaki sıra (1'den); açık ama bitmemiş düğümde numara olarak yazılır.
  final int step;

  /// Dersin ikonu (güncel düğümde beyaz, iri).
  final IconData icon;

  /// Düğümün yanındaki ad. Güncel düğümde `null` olabilir: ad, altındaki
  /// kartta yazar (aynı ad ekranda iki kez görünmesin).
  final String? title;

  /// Adın altındaki kısa durum satırı ("Tamamlandı").
  final Widget? status;
  final String semanticLabel;

  /// `null` → kilitli (dokununca kilit titrer, ses çıkmaz).
  final VoidCallback? onTap;

  /// Güncel düğümün altındaki kart.
  final Widget? attachment;

  /// Durağın (ve kartının) ARDINDAN, sarmalayıcının DIŞINDA duran parça —
  /// kendi düğmeleri olan bir davet ("Seviyeni bul"): güncel durağın tek
  /// düğme semantiğine karışmaz.
  final Widget? after;

  /// Durağı (satır + kart) saran anahtar/semantik katmanı — test
  /// sözleşmesi çağıranın elindedir (`learning-path-node-…`).
  final Widget Function(Widget child)? wrap;
}

/// Düğüm ölçüleri.
class LearnPathMetrics {
  const LearnPathMetrics._();

  /// Sıradan düğüm.
  static const double node = 64;

  /// Güncel düğüm (halka hariç).
  static const double current = 80;

  /// Güncel düğümün halkası ve halka ile düğüm arasındaki boşluk.
  static const double ring = 3;
  static const double ringGap = 4;

  /// Düğümün altındaki kabartma tabanı.
  static const double base = 5;

  /// Yolun kalınlığı.
  static const double stroke = 10;

  /// Güncel düğümün satırında düğümün üstü + altındaki toplam nefes
  /// (son kurul tur 3; sıradan satırda 20).
  static const double currentBreath = 4;

  /// Büyük yazıda (≥ ×1,5) düğümler küçülür ve yol düzleşir: dar telefonda
  /// ders adı harf harf bölünmesin (320 pt + ×2: "Selamlaş / ma").
  static const double compactNode = 52;
  static const double compactCurrent = 64;

  static double nodeFor({required bool current, required bool compact}) =>
      compact
      ? (current ? compactCurrent : compactNode)
      : (current ? LearnPathMetrics.current : node);

  static double slotFor({required bool current, required bool compact}) =>
      nodeFor(current: current, compact: compact) +
      (current ? 2 * (ringGap + ring) : base);
}

/// Kıvrımlı ders yolu.
class LearnPath extends StatelessWidget {
  const LearnPath({required this.stops, super.key});

  final List<LearnPathStop> stops;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        // Büyük yazıda yolun salınımı daralır: ad için yer kalsın.
        final compact = scale >= 1.5;
        final amp = compact ? 0.0 : math.min(width * 0.12, 44.0);
        final half =
            LearnPathMetrics.slotFor(current: true, compact: compact) / 2;
        final xs = [
          for (var i = 0; i < stops.length; i++)
            half + 4 + amp * (1 + math.sin(i * math.pi / 2.5)),
        ];
        final children = <Widget>[];
        for (var i = 0; i < stops.length; i++) {
          final stop = stops[i];
          final prev = i > 0 ? stops[i - 1] : null;
          final next = i + 1 < stops.length ? stops[i + 1] : null;
          final row = _LearnPathRow(
            stop: stop,
            x: xs[i],
            prevX: prev == null ? null : xs[i - 1],
            nextX: next == null ? null : xs[i + 1],
            inDone: prev != null && prev.state == LearnNodeState.done,
            outDone: stop.state == LearnNodeState.done,
            textScale: scale,
          );
          Widget block = row;
          if (stop.attachment != null) {
            block = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row,
                _Caret(x: xs[i], color: SahneTokens.of(context).learnFill),
                stop.attachment!,
                const SizedBox(height: SahneSpace.x2),
              ],
            );
          }
          children.add(stop.wrap?.call(block) ?? block);
          if (stop.after != null) {
            children
              ..add(stop.after!)
              ..add(const SizedBox(height: SahneSpace.x2));
          }
        }
        return Column(
          key: const ValueKey('learn-path'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// Kartın tepesinde güncel düğüme bakan 10 px'lik uç.
class _Caret extends StatelessWidget {
  const _Caret({required this.x, required this.color});

  final double x;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 10,
        child: CustomPaint(painter: _CaretPainter(x, color)),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.x, this.color);

  final double x;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(x - 12, size.height + 1)
      ..lineTo(x, 0)
      ..lineTo(x + 12, size.height + 1)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.x != x || old.color != color;
}

class _LearnPathRow extends StatefulWidget {
  const _LearnPathRow({
    required this.stop,
    required this.x,
    required this.prevX,
    required this.nextX,
    required this.inDone,
    required this.outDone,
    required this.textScale,
  });

  final LearnPathStop stop;
  final double x;
  final double? prevX;
  final double? nextX;
  final bool inDone;
  final bool outDone;
  final double textScale;

  @override
  State<_LearnPathRow> createState() => _LearnPathRowState();
}

class _LearnPathRowState extends State<_LearnPathRow> {
  /// Kilitli düğüme her dokunuşta artar; kilit titrer (sessiz kalmasın).
  int _nudge = 0;

  void _nudgeLock() {
    AppHaptics.selection();
    setState(() => _nudge++);
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final stop = widget.stop;
    final current = stop.state == LearnNodeState.current;
    final locked = stop.state == LearnNodeState.locked;
    final compact = widget.textScale >= 1.5;
    final nodeSlot = LearnPathMetrics.slotFor(
      current: current,
      compact: compact,
    );
    // Satır yüksekliği: düğüm + nefes ya da iki satırlık ad + durum.
    // Satır en az düğüm + 20 yüksekliğinde; ad/rozetler uzarsa (büyük yazı)
    // satır onlarla uzar, düğüm dikeyde ortada kalır.
    //
    // 2026-10-29 son kurul tur 3 (Astra + Sol + Terra): güncel düğümün
    // satırında yanında ad yoktur (ad kartta); 20'lik nefes düğümü kartından
    // ayırıp ilk ekranı dolduruyordu. Güncel satırda nefes 4: düğüm, ucu ve
    // kartı tek bir birim gibi okunur.
    final minHeight =
        nodeSlot + (current ? LearnPathMetrics.currentBreath : 20);
    final done = t.learnFill;
    final todo = t.s3;
    final labelStart = widget.x + nodeSlot / 2 + SahneSpace.x3;

    Widget node = _LearnNode(
      state: stop.state,
      step: stop.step,
      icon: stop.icon,
      compact: compact,
    );
    if (locked) {
      node = TweenAnimationBuilder<double>(
        key: ValueKey('learn-node-nudge-$_nudge'),
        tween: Tween(begin: _nudge == 0 ? 1 : 0, end: 1),
        duration: Duration(milliseconds: _reduceMotion(context) ? 0 : 360),
        builder: (context, v, child) => Transform.translate(
          offset: Offset(6 * math.sin(v * math.pi * 4) * (1 - v), 0),
          child: child,
        ),
        child: node,
      );
    }

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stop.title != null)
          Text(
            stop.title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SahneType.bodyStrong.copyWith(
              // Kilitli ders soluklaştırılmaz (okunurluk); ikincil metin.
              color: locked ? t.tx2 : t.tx,
            ),
          ),
        if (stop.status != null) ...[
          if (stop.title != null) const SizedBox(height: 2),
          stop.status!,
        ],
      ],
    );

    final body = Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: _RowPathPainter(
                x: widget.x,
                prevX: widget.prevX,
                nextX: widget.nextX,
                inColor: widget.inDone ? done : todo,
                outColor: widget.outDone ? done : todo,
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight,
            minWidth: double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.only(left: labelStart, top: 10, bottom: 10),
            child: Align(alignment: Alignment.centerLeft, child: label),
          ),
        ),
        Positioned(
          left: widget.x - nodeSlot / 2,
          top: 0,
          bottom: 0,
          width: nodeSlot,
          child: Center(child: node),
        ),
      ],
    );

    if (current) {
      // Güncel durağın semantiği ve dokunuşu çağıranın sarmalayıcısında
      // (satır + kart tek düğme).
      return ExcludeSemantics(child: body);
    }
    return Semantics(
      button: !locked,
      enabled: !locked,
      label: stop.semanticLabel,
      onTap: stop.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: locked ? _nudgeLock : stop.onTap,
        child: body,
      ),
    );
  }
}

/// Satırın yol parçası: üstteki orta noktadan düğüme, düğümden alttaki orta
/// noktaya. Uçlarda teğet dikeydir; iki yarım birleşince yumuşak S olur.
class _RowPathPainter extends CustomPainter {
  const _RowPathPainter({
    required this.x,
    required this.prevX,
    required this.nextX,
    required this.inColor,
    required this.outColor,
  });

  final double x;
  final double? prevX;
  final double? nextX;
  final Color inColor;
  final Color outColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.height / 2;
    Paint pen(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = LearnPathMetrics.stroke
      ..strokeCap = StrokeCap.round;
    if (prevX != null) {
      final m = (prevX! + x) / 2;
      final path = Path()
        ..moveTo(m, 0)
        ..cubicTo(m, c * 0.6, x, c * 0.4, x, c);
      canvas.drawPath(path, pen(inColor));
    }
    if (nextX != null) {
      final m = (nextX! + x) / 2;
      final h = size.height;
      final path = Path()
        ..moveTo(x, c)
        ..cubicTo(x, c + (h - c) * 0.6, m, c + (h - c) * 0.4, m, h);
      canvas.drawPath(path, pen(outColor));
    }
  }

  @override
  bool shouldRepaint(_RowPathPainter old) =>
      old.x != x ||
      old.prevX != prevX ||
      old.nextX != nextX ||
      old.inColor != inColor ||
      old.outColor != outColor;
}

/// Kabartmalı yuvarlak düğüm: yüz + altta 5 px koyu taban (hacimli
/// birincil düğmenin dili). Güncel düğümde dışta 3 px halka.
class _LearnNode extends StatelessWidget {
  const _LearnNode({
    required this.state,
    required this.step,
    required this.icon,
    this.compact = false,
  });

  final LearnNodeState state;
  final int step;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final current = state == LearnNodeState.current;
    final size = LearnPathMetrics.nodeFor(current: current, compact: compact);
    final (Color face, Color glyph) = switch (state) {
      LearnNodeState.done ||
      LearnNodeState.current => (t.learnFill, Colors.white),
      LearnNodeState.open => (t.learnTint, t.learnTx),
      LearnNodeState.locked => (t.s3, t.tx2),
    };
    final base = Color.lerp(
      face,
      Colors.black,
      state == LearnNodeState.locked ? 0.14 : 0.28,
    )!;
    final Widget mark = switch (state) {
      LearnNodeState.done => Icon(AppIcons.check, size: 28, color: glyph),
      LearnNodeState.current => Icon(icon, size: 34, color: glyph),
      LearnNodeState.open => Text(
        groupThousands(step),
        style: SahneType.headline.copyWith(color: glyph),
      ),
      LearnNodeState.locked => Icon(AppIcons.lock, size: 22, color: glyph),
    };
    Widget coin = SizedBox(
      key: ValueKey('learn-node-${state.name}'),
      width: size,
      height: size + LearnPathMetrics.base,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: face,
                border: state == LearnNodeState.open
                    ? Border.all(color: t.learnFill, width: 2)
                    : null,
                gradient: state == LearnNodeState.locked
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(face, Colors.white, 0.16)!, face],
                      ),
              ),
              child: Center(child: mark),
            ),
          ),
        ],
      ),
    );
    if (current) {
      final slot = LearnPathMetrics.slotFor(current: true, compact: compact);
      const inset = LearnPathMetrics.ringGap + LearnPathMetrics.ring;
      coin = SizedBox.square(
        dimension: slot,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                key: const ValueKey('learn-node-current-ring'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: t.learnFill,
                    width: LearnPathMetrics.ring,
                  ),
                ),
              ),
            ),
            Positioned(
              left: inset,
              top: inset - LearnPathMetrics.base / 2,
              child: coin,
            ),
          ],
        ),
      );
    }
    return coin;
  }
}

/// Ünite başı sahnesi: manzara + rehber maskot + ünite adı + ilerleme.
class LearnUnitScene extends StatelessWidget {
  const LearnUnitScene({
    required this.eyebrow,
    required this.title,
    required this.done,
    required this.total,
    required this.countLabel,
    super.key,
  });

  /// "Ünite 1".
  final String eyebrow;

  /// Konu adı ("Gündelik hayat").
  final String title;
  final int done;
  final int total;

  /// "0/5 ders".
  final String countLabel;

  /// Manzara bandı. 2026-10-29 son kurul tur 3 (üç model): ünite kartı +
  /// güncel düğüm + Başla kartı 390×844'te ilk ekranı tamamen dolduruyor,
  /// rotanın devamı görünmüyordu. Bant 92 → 68, rehber maskot 116 → 92;
  /// manzara ve maskot yerinde kalır, yalnız alçalır.
  static const double vistaHeight = 68;
  static const double mascotSize = 92;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final night = t.bg.computeLuminance() < 0.2;
    final phase = night ? SahneVistaPhase.night : SahneVistaPhase.day;
    return SahneSurfaceCard(
      key: const ValueKey('learn-unit-scene'),
      padding: EdgeInsets.zero,
      color: t.learnTint,
      edgeColor: Color.lerp(t.learnTint, t.learnFill, 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SahneShape.lValue - 1),
              ),
              child: SizedBox(
                height: vistaHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: SahneVistaPainter.of(
                        phase,
                        part: SahneVistaPart.back,
                        sunLeft: true,
                      ),
                    ),
                    const PositionedDirectional(
                      end: 8,
                      bottom: 2,
                      child: ZanMascot(
                        key: ValueKey('learn-unit-mascot'),
                        pose: ZanPose.guide,
                        size: mascotSize,
                      ),
                    ),
                    CustomPaint(
                      painter: SahneVistaPainter.of(
                        phase,
                        part: SahneVistaPart.front,
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SahneKilimBorder(
                        color: SahneKilimBorderPainter.darkOn,
                        height: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SahneSpace.x4,
              SahneSpace.x3,
              SahneSpace.x4,
              SahneSpace.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: SahneSpace.x2,
                  children: [
                    Text(
                      eyebrow,
                      style: SahneType.eyebrow.copyWith(color: t.learnTx),
                    ),
                    Text(
                      countLabel,
                      style: SahneType.captionStrong.copyWith(
                        color: t.tx,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
                const SizedBox(height: SahneSpace.x3),
                _SegmentedProgress(
                  done: done,
                  total: total,
                  semanticLabel: '$eyebrow. $countLabel',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Beş parçalı 8 px ilerleme (Astra: "ince, soluk çizgi yerine").
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.done,
    required this.total,
    required this.semanticLabel,
  });

  final int done;
  final int total;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final n = math.max(total, 1);
    return Semantics(
      label: semanticLabel,
      value: '${groupThousands(done)}/${groupThousands(total)}',
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('learn-unit-progress'),
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: i < done ? t.learnFill : t.s1,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: i < done
                          ? t.learnFill
                          : Color.lerp(t.learnTint, t.learnFill, 0.35)!,
                    ),
                  ),
                ),
                child: const SizedBox(height: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Hareketi azalt" açık mı (`MediaQuery.disableAnimationsOf` ya da
/// uygulama tercihi; [sahneMotionReduced]). Açıkken kilit titremesi ve
/// düğüm hareketi yok, rota sabit çizilir.
bool _reduceMotion(BuildContext context) => sahneMotionReduced(context);
