import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'sahne/sahne.dart';

/// Bir rehber turu adımı: hedef widget'ın konumu + açıklayıcı metin.
class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.icon,
    required this.title,
    required this.description,
  });

  final GlobalKey targetKey;
  final IconData icon;
  final String title;
  final String description;
}

/// Ekranın üstüne bindirilen, hedef widget'ı aydınlık bırakıp gerisini
/// karartan ve yanına açıklayıcı balon gösteren basit bir rehber turu.
///
/// Paket bağımlılığı yok: CustomPainter ile "spotlight" deliği çizilir,
/// tooltip balonu hedefin üstünde/altında (yer varsa) konumlanır.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    required this.steps,
    required this.onFinished,
    this.onBeforeStep,
    this.isKu = false,
    this.ancestorKey,
    super.key,
  });

  final List<CoachMarkStep> steps;
  final VoidCallback onFinished;

  /// Bir sonraki adım ölçülmeden önce çalışır; hedefi kaydırılabilir bir
  /// alanda görünür kılmak isteyen turlar için kullanılır.
  final Future<void> Function(int nextIndex)? onBeforeStep;
  final bool isKu;

  /// Hedef konumunun göreceli olarak hesaplanacağı üst widget'ın key'i.
  /// Masaüstü genişliğinde uygulama ResponsiveWrapper tarafından ortalanmış
  /// dar bir çerçeveye sığdırılıyor; bu durumda "gerçek ekran köküne göre"
  /// global koordinat almak yanlış konum verir. Bunun yerine hedefin
  /// konumu, overlay ile aynı Stack'in kökü olan bu ata'ya göre hesaplanır.
  final GlobalKey? ancestorKey;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _index = 0;
  Rect? _rect;
  int _measuredForIndex = -1;
  // Gerçekten GÖSTERİLEN adım sayısı: hedefi mount olmayan adımlar atlanır,
  // sayaç yine de ilk görülen adımda "1/..." başlasın diye ayrı tutulur.
  int _shownCount = 0;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  /// Hedefin konumunu build sırasında DEĞİL, bir sonraki frame'de ölçer.
  /// Build anında RenderBox.localToGlobal çağırmak, ağaç henüz tam layout
  /// olmadan (ör. sayfa geçiş animasyonu sürerken) "hasSize" assertion'ına
  /// çarpabiliyor — bu yüzden ölçüm her zaman post-frame'e ertelenir.
  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = widget.steps[_index].targetKey;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) {
        // Hedef hiç mount olmamış (ör. bu tab hiç açılmadı) — bu adımı atla.
        _next();
        return;
      }
      final ancestorBox =
          widget.ancestorKey?.currentContext?.findRenderObject() as RenderBox?;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: ancestorBox);
      setState(() {
        _rect = topLeft & box.size;
        _measuredForIndex = _index;
        _shownCount++;
      });
    });
  }

  Future<void> _next() async {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
      return;
    }
    final nextIndex = _index + 1;
    await widget.onBeforeStep?.call(nextIndex);
    if (!mounted) return;
    setState(() {
      _index = nextIndex;
      _rect = null;
    });
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final screenSize = MediaQuery.sizeOf(context);
    final rect = _measuredForIndex == _index ? _rect : null;

    if (rect == null) {
      return const SizedBox.shrink();
    }

    final highlightRect = rect.inflate(8);
    // Tooltip için tahmini yükseklik: hedefin altında yer yoksa (balon
    // karartılmış alanın dışına taşıp okunamaz hale geliyorsa) üstte göster.
    const estimatedBubbleHeight = 220.0;

    // Balonu hedefe *yapıştırmak*, ekranın kenarındaki hedeflerde asıl
    // içeriği örtüyordu: sayaç sağ üstte olduğu için "hemen altı" tam da
    // soru metninin durduğu yerdi ve tur boyunca soru okunamıyordu; aynı
    // şekilde en alttaki "Sonraki" butonunun "hemen üstü" şıkların üstüne
    // düşüyordu (2026-07-25 canlı denetimi).
    //
    // Işık halkası (spotlight) hedefi zaten işaret ediyor; balonun bitişik
    // olması şart değil. Kenardaki hedeflerde balon karşı kenara sabitlenir,
    // böylece hem hedef hem içerik açıkta kalır. Ortadaki hedeflerde eski
    // bitişik yerleşim korunur.
    final topZone = screenSize.height / 3;
    final bottomZone = screenSize.height * 2 / 3;

    double? tooltipTop;
    double? tooltipBottom;

    if (highlightRect.bottom <= topZone) {
      // Hedef üst şeritte → balon ekranın altına.
      tooltipBottom = 24;
    } else if (highlightRect.top >= bottomZone) {
      // Hedef alt şeritte → balon ekranın üstüne.
      tooltipTop = MediaQuery.paddingOf(context).top + 16;
    } else {
      // Balon hedefin altına mı üstüne mi?
      //
      // İki kusur peş peşe çıktı (2026-07-27, canlı denemeler):
      // önce üstte konumlanan balon başlığın üzerine biniyordu; onu
      // aşağı alınca bu kez ekranın altından taşıp düğmeleri
      // görünmez yaptı. Sebep aynı: yalnız "sığıyor mu" bakılıyor,
      // sığmadığında ne yapılacağı tanımlı değildi.
      //
      // Kural: her iki tarafın gerçek boşluğu ölçülür. Balon sığan
      // tarafa konur; hiçbir tarafa sığmıyorsa boşluğu fazla olan
      // kenara **sabitlenir** — hedefin üstünü bir miktar örtebilir,
      // ama ışık halkası hedefi zaten gösteriyor ve balonun tümüyle
      // görünmesi düğmeleri erişilebilir kılar.
      final safeTop = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
      const safeBottom = 24.0;
      final roomAbove = highlightRect.top - 16 - safeTop;
      final roomBelow =
          screenSize.height - safeBottom - (highlightRect.bottom + 16);

      if (roomBelow >= estimatedBubbleHeight) {
        tooltipTop = highlightRect.bottom + 16;
      } else if (roomAbove >= estimatedBubbleHeight) {
        tooltipBottom = screenSize.height - highlightRect.top + 16;
      } else if (roomBelow >= roomAbove) {
        tooltipBottom = safeBottom;
      } else {
        tooltipTop = safeTop;
      }
    }

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _next();
                },
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    highlightRect,
                    ring: SahneTokens.of(context).gold,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              left: SahneSpace.page,
              right: SahneSpace.page,
              top: tooltipTop,
              bottom: tooltipBottom,
              child: _CoachMarkBubble(
                step: step,
                index: _shownCount - 1,
                total: widget.steps.length,
                isKu: widget.isKu,
                onNext: () {
                  _next();
                },
                onSkip: widget.onFinished,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karartma + hedefin çevresinde pahlı ışık deliği.
///
/// 2026-09-29 Şahnê: perde gecenin zemini (`night.bg`, %80), delik M pah,
/// kenarı Halka 2 Zêr (ışık); eski Agir kontur birincil eylem rengini
/// süs olarak kullanıyordu.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.rect, {required this.ring});

  final Rect rect;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = SahneShape.m.getOuterPath(rect);
    final combined = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(
      combined,
      Paint()..color = SahneTokens.night.bg.withValues(alpha: 0.8),
    );
    canvas.drawPath(
      hole,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = SahneRing.r2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.ring != ring;
}

class _CoachMarkBubble extends StatelessWidget {
  const _CoachMarkBubble({
    required this.step,
    required this.index,
    required this.total,
    required this.isKu,
    required this.onNext,
    required this.onSkip,
  });

  final CoachMarkStep step;
  final int index;
  final int total;
  final bool isKu;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isLast = index == total - 1;
    // 2026-09-29 Şahnê: balon yüzey kartıdır (Perde, L pah, gündüzde 1 px
    // kenar), bulanık gölge yok. İkon karosu nötr Kulis tonu (M pah);
    // başlık Gövde 700, sayaç kalın açıklama (tablo rakamı), açıklama
    // ikincil metin. "Atla" metin düğmesi, "İleri/Anladım" ekranın
    // o anki tek birincil eylemi. Açıklama Açıklama biçemindedir.
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.s1,
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: t.roleTint(SahneRole.gold),
                    shape: SahneShape.m,
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Icon(
                      step.icon,
                      color: t.roleText(SahneRole.gold),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    step.title,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                ),
                Text(
                  '${index + 1}/$total',
                  style: SahneType.captionStrong.copyWith(
                    color: t.tx3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x3),
            // Açıklama boyu: balon hedefin karşı kenarına sabitlendiğinde
            // (ör. öğrenme turunda şıklar ekranın ortasında) içeriği
            // örtmemesi için kısa kalmalı (`quiz_tutorial_learning_layout`).
            Text(
              step.description,
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x4),
            Row(
              children: [
                SahneButton.text(
                  label: Tr.forKu(K.skip, isKu),
                  onPressed: onSkip,
                  arrow: false,
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: SahneButton.primary(
                    label: isLast
                        ? (Tr.forKu(K.anladim, isKu))
                        : (Tr.forKu(K.nextStep, isKu)),
                    onPressed: onNext,
                    arrow: !isLast,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
