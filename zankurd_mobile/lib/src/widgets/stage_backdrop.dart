import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/sahne.dart';

/// Yarışma sahnesi fonu: altın ışın hüzmeleri, odakta bir parıltı ve
/// kenarlarda konfeti.
///
/// 2026-09-27: sahip Yarış sekmesini "renksiz" buldu; sakin bir menü gibi
/// duruyordu. Hızlı düello kartı bu fonla bir yarışma sahnesine döndü (TRT
/// "Bil Bakalım", Kahoot, QuizUp). Sıralama podyumu da aynı sahneyi
/// kullanacağı için çizici ekrana gömülü değil, burada durur.
///
/// ## Konfeti niçin kenarlarda ve piksel cinsinden
///
/// İlk sürüm konfetiyi kartın genişliğine VE yüksekliğine oranla yerleştirdi.
/// Kartın içeriği ise üstten SABİT piksel uzaklıkta durur: kart uzayınca
/// (Kurmancî başlık iki satıra inince, büyük yazıda) konfeti aşağı kayıp
/// oyuncu dairelerinin içine düştü — tur görüntüsünde bir elmas "Sen"
/// dairesinin içindeydi. Konfeti artık yalnız iki kenar şeridinde
/// (`dx ≤ 0.10`, `dx ≥ 0.90`) ve kartın ilk 12 pikselindeki bantta durur;
/// dikey konumu kartın tepesinden piksel olarak ölçülür. Bekçi:
/// `test/play_hub_stage_test.dart` konfetinin hiçbir metin ya da ikonla
/// kesişmediğini ölçer.
///
/// Desen sabittir (Random yok): ekran turu ve testler her koşuda aynı
/// kareyi görmeli.
class StageBackdropPainter extends CustomPainter {
  const StageBackdropPainter({
    this.focusTop = 70,
    this.rayCount = 14,
    this.glowRadius = 96,
    this.confetti = true,
  });

  /// Işınların ve parıltının merkezi: yatayda ortada, kartın tepesinden bu
  /// kadar piksel aşağıda. Kart uzasa da odak, üstten sabit duran içerikle
  /// (düelloda VS rozeti) hizalı kalır.
  final double focusTop;
  final int rayCount;
  final double glowRadius;
  final bool confetti;

  static const double _raySpreadDegrees = 6;

  /// Kartın içinde konfetinin kaplayacağı dikdörtgenler (yerel koordinat).
  /// Çizim ve bekçi aynı hesabı kullanır.
  static List<Rect> confettiRects(Size size) => [
    for (final piece in _pieces)
      Rect.fromCenter(
        center: Offset(size.width * piece.dx, piece.top),
        width: piece.size,
        height: piece.size,
      ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final focus = Offset(
      size.width * 0.5,
      math.min(focusTop, size.height * 0.5),
    );

    // 2026-09-29 Şahnê: ışınlar ve hale paletten — sonuç ışını
    // (`SahneStageColors.ray`) ve altın hale (`haloGold`).
    final rayPaint = Paint()..color = SahneStageColors.ray;
    const spread = _raySpreadDegrees * math.pi / 180;
    final length = math.max(size.width, size.height);
    for (var i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi / rayCount) * i;
      final p1 = focus + Offset.fromDirection(angle - spread / 2, length);
      final p2 = focus + Offset.fromDirection(angle + spread / 2, length);
      canvas.drawPath(
        Path()
          ..moveTo(focus.dx, focus.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close(),
        rayPaint,
      );
    }

    canvas.drawCircle(
      focus,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SahneStageColors.haloGold,
            SahneStageColors.haloGold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: focus, radius: glowRadius)),
    );

    if (!confetti) return;
    final rects = confettiRects(size);
    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      final rect = rects[i];
      final paint = Paint()..color = piece.color.withValues(alpha: piece.alpha);
      if (piece.diamond) {
        canvas.drawPath(
          Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.center.dy)
            ..lineTo(rect.center.dx, rect.bottom)
            ..lineTo(rect.left, rect.center.dy)
            ..close(),
          paint,
        );
      } else {
        canvas.drawCircle(rect.center, piece.size / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(StageBackdropPainter oldDelegate) =>
      oldDelegate.focusTop != focusTop ||
      oldDelegate.rayCount != rayCount ||
      oldDelegate.glowRadius != glowRadius ||
      oldDelegate.confetti != confetti;
}

class _ConfettiPiece {
  const _ConfettiPiece(
    this.dx,
    this.top,
    this.size,
    this.color,
    this.alpha, {
    this.diamond = false,
  });

  /// Yatay konum, kart genişliğine oran (0..1).
  final double dx;

  /// Dikey konum, kartın tepesinden piksel.
  final double top;
  final double size;
  final Color color;
  final double alpha;
  final bool diamond;
}

// Üst bant yalnız kartın ilk 12 pikselinde durur: başlık (düelloda "Hızlı
// düello") 16. pikselde başlar ve Kurmancîde neredeyse kart genişliğindedir.
// Kenar şeritleri koltuk satırının hizasındadır; koltuklar ve etiketleri
// sütunlarının ortasında durduğu için şeride uzanmaz.
// Renkler rol paletinden: gecenin krem metni, Zêr, Boyax'ın yumuşak tonu ve
// Boyax. Agir yalnız birincil eylemin dolgusudur; süste kullanılmaz.
// Sahne her zaman gecedir: gece belirteçleri.
final _cream = SahneTokens.night.tx;
final _gold = SahneTokens.night.gold;
final _race = SahneTokens.night.race;
const _raceSoft = SahneStageColors.raceSoft;

final _pieces = <_ConfettiPiece>[
  _ConfettiPiece(0.12, 8, 5, _cream, 0.62, diamond: true),
  _ConfettiPiece(0.24, 5, 5, _gold, 0.70),
  const _ConfettiPiece(0.76, 7, 5, _raceSoft, 0.62, diamond: true),
  _ConfettiPiece(0.88, 5, 5, _cream, 0.60),
  _ConfettiPiece(0.05, 52, 7, _gold, 0.75),
  const _ConfettiPiece(0.09, 70, 6, _raceSoft, 0.65, diamond: true),
  _ConfettiPiece(0.04, 88, 5, _cream, 0.60),
  _ConfettiPiece(0.08, 106, 6, _race, 0.70, diamond: true),
  _ConfettiPiece(0.95, 50, 7, _gold, 0.70, diamond: true),
  _ConfettiPiece(0.91, 68, 6, _race, 0.60),
  _ConfettiPiece(0.96, 86, 6, _cream, 0.58, diamond: true),
  const _ConfettiPiece(0.92, 104, 5, _raceSoft, 0.68),
];
