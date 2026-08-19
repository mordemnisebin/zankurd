import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Turun dokuma kaydı: her soru bir baklava, doğru cevap altın iplik.
///
/// ## Niçin bu bileşen var
///
/// İlerleme şeridi, soru ekranında HER soruda görünen tek öğedir; yani
/// uygulamanın görsel kimliğinin en çok kazandığı yer burasıdır. Eskiden
/// yuvarlak köşeli düz çubuklardan oluşuyordu — doğru bilgiyi taşıyordu
/// ama hiçbir şey söylemiyordu; her yarışma uygulamasında aynısı var.
/// Kimlik bileşenleri (`RojMascot`, `KilimReveal`, `ArenaKit`) ise
/// onboarding, mağaza ve liderlik gibi kullanıcının nadiren uğradığı
/// ekranlara sıkışmıştı. Kimlik kenarda, çekirdek döngü kimliksizdi.
///
/// Bu şerit aynı veriyi kilim diliyle söyler: tur ilerledikçe dokunan bir
/// motif sırası. Sonunda ortaya kullanıcının o turda ördüğü, paylaşmaya
/// değer bir nesne çıkar.
///
/// ## Niçin doğru ALTIN DOLU, yanlış İÇİ BOŞ
///
/// Beklenen eşleme yeşil/kırmızıydı. İki nedenle kullanılmadı:
///
/// 1. Dokumada hata kırmızı iplik değildir, motifte bir boşluktur. Boş
///    baklava dokumanın kendi dilidir; kırmızı çubuk yazılım dilidir.
/// 2. Yeşil/kırmızı ayrımı deuteranopide ve gri tonlamada kaybolur.
///    Dolu/boş ayrımı bir BİÇİM farkıdır; renk görmeyen kullanıcıda da,
///    ekran görüntüsü siyah beyaz basıldığında da ayakta kalır. Şerit
///    paylaşılabilir bir nesne olduğu için ikincisi teorik değil.
class KilimBoard extends StatelessWidget {
  const KilimBoard({
    required this.total,
    required this.currentIndex,
    required this.results,
    this.height = 22,
    this.showCurrent = true,
    super.key,
  });

  /// Turdaki toplam soru sayısı.
  final int total;

  /// Şu an bekleyen sorunun sırası. Tur bittiyse [total] verilebilir.
  final int currentIndex;

  /// Cevaplanmış soruların sonuçları; sıra [results] uzunluğu kadar dolar.
  final List<bool> results;

  final double height;

  /// Sonuç ekranında tur bitmiştir; "sıradaki soru" vurgusu anlamsızdır.
  final bool showCurrent;

  /// Motifin okunabildiği asgari baklava genişliği.
  ///
  /// Bunun altında baklavalar birbirine girip şeridi gri bir tarağa
  /// çeviriyor. 40 soruluk sınav modunda tam olarak bu oluyordu; o
  /// durumda tek tek soru göstermek zaten bilgi vermiyor, oran veriyor.
  static const double minCellWidth = 9;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticsLabel(context),
      child: SizedBox(
        key: const ValueKey('kilim-board'),
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _KilimBoardPainter(
            total: total,
            currentIndex: showCurrent ? currentIndex : -1,
            results: results,
            trackColor: AppTheme.surfaceHiColor(context),
            outlineColor: AppTheme.borderColor(context),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel(BuildContext context) {
    final correct = results.where((result) => result).length;
    return '$total sorudan ${results.length} cevaplandı, $correct doğru';
  }
}

class _KilimBoardPainter extends CustomPainter {
  const _KilimBoardPainter({
    required this.total,
    required this.currentIndex,
    required this.results,
    required this.trackColor,
    required this.outlineColor,
  });

  final int total;
  final int currentIndex;
  final List<bool> results;
  final Color trackColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || total <= 0) return;

    final cellWidth = size.width / total;
    if (cellWidth < KilimBoard.minCellWidth) {
      _paintCompact(canvas, size);
      return;
    }

    // Baklavalar arasında ince bir pay bırakılır; bitişik çizildiklerinde
    // kenarlar kaynayıp tek bir zikzak şeride dönüşüyor ve soru sayısı
    // sayılamaz oluyordu.
    final gap = (cellWidth * 0.16).clamp(1.5, 4.0);
    final width = cellWidth - gap;
    final halfHeight = size.height / 2;

    for (var i = 0; i < total; i++) {
      final centerX = cellWidth * i + cellWidth / 2;
      final diamond = Path()
        ..moveTo(centerX, 0)
        ..lineTo(centerX + width / 2, halfHeight)
        ..lineTo(centerX, size.height)
        ..lineTo(centerX - width / 2, halfHeight)
        ..close();

      if (i < results.length) {
        if (results[i]) {
          canvas.drawPath(diamond, Paint()..color = AppTheme.gold);
        } else {
          // Boş baklava: motifte bırakılan gedik. Çerçeve altının soluk
          // tonundadır ki gedik "eksik iplik" gibi okunsun, ayrı bir
          // uyarı rengi gibi değil.
          canvas.drawPath(
            diamond,
            Paint()
              ..color = AppTheme.gold.withValues(alpha: 0.42)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
      } else if (i == currentIndex) {
        canvas.drawPath(diamond, Paint()..color = AppTheme.brand);
      } else {
        canvas.drawPath(diamond, Paint()..color = trackColor);
        canvas.drawPath(
          diamond,
          Paint()
            ..color = outlineColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  /// Uzun setlerde motif okunmaz; oranı taşıyan dolu şeride düşülür.
  void _paintCompact(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = trackColor);

    final answered = results.length / total;
    if (answered <= 0) return;
    final correct = results.where((result) => result).length / total;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.width * answered, size.height),
        radius,
      ),
      Paint()..color = AppTheme.gold.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.width * correct, size.height),
        radius,
      ),
      Paint()..color = AppTheme.gold,
    );
  }

  @override
  bool shouldRepaint(_KilimBoardPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.currentIndex != currentIndex ||
      oldDelegate.results.length != results.length ||
      oldDelegate.trackColor != trackColor;
}
