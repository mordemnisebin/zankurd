import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bir metnin EKRANDA çizildiği gerçek punto boyu.
///
/// Stil boyu × yazı ölçeği × ata dönüşümlerinin ölçeği (FittedBox,
/// Transform.scale ...). Kapışma U13 (2026-10-29): "caption 14" tokenı tek
/// başına güvence değildi — FittedBox aynı tokenla çizilen "En uzun seri"
/// sözünü ≈8 pt'ye indiriyordu. Bekçiler stile değil buna bakar.
double renderedFontSize(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final span = paragraph.text;
  final base = span.style?.fontSize ?? 14;
  final scaled = paragraph.textScaler.scale(base);
  final transform = paragraph.getTransformTo(null);
  // Yalnız eşit ölçek beklenir; y ekseni ölçeği yeterli.
  final scaleY = transform.getMaxScaleOnAxis();
  return scaled * scaleY;
}

/// Projenin okunur alt sınırı: `SahneType.caption` = 14 pt (yazı 1.0'da).
const kOkunurAltSinir = 14.0;
