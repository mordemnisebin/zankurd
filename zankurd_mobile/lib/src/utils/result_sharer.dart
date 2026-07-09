import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/share_result_card.dart';

/// Quiz sonucunu markalı bir kart görseli olarak paylaşır.
///
/// Kart ekran dışında render edilip PNG'ye çevrilir ve share_plus ile
/// paylaşılır. Görsel üretimi herhangi bir nedenle başarısız olursa,
/// güvenli biçimde metin paylaşımına düşülür (her platformda çalışır).
class ResultSharer {
  static Future<void> share(
    BuildContext context, {
    required bool isKu,
    required int score,
    required int correctCount,
    required int totalQuestions,
    required int bestStreak,
    required String category,
  }) async {
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();
    final text = isKu
        ? 'Min di ZanKurd de $score pûan girt! '
              'Rast: $correctCount/$totalQuestions (%$accuracy). '
              'Tu jî bilîze: Play Store → "ZanKurd"'
        : 'ZanKurd\'te $score puan aldım! '
              'Doğru: $correctCount/$totalQuestions (%$accuracy). '
              'Sen de oyna: Play Store → "ZanKurd"';

    final overlay = Overlay.maybeOf(context);
    Uint8List? bytes;
    if (overlay != null) {
      bytes = await _captureCard(
        overlay,
        ShareResultCard(
          isKu: isKu,
          score: score,
          correctCount: correctCount,
          totalQuestions: totalQuestions,
          bestStreak: bestStreak,
          category: category,
        ),
      );
    }

    try {
      if (bytes != null) {
        final file = XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'zankurd_result.png',
        );
        await Share.shareXFiles([file], text: text);
        return;
      }
    } catch (_) {
      // Görsel paylaşımı başarısız — metne düş.
    }
    await Share.share(text);
  }

  /// Verilen widget'ı ekran dışında render edip PNG byte'larına çevirir.
  static Future<Uint8List?> _captureCard(
    OverlayState overlay,
    Widget card,
  ) async {
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        // Görünür alanın dışında; yine de layout edilip boyanır.
        left: -4000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(key: boundaryKey, child: card),
        ),
      ),
    );

    try {
      overlay.insert(entry);
      // Kartın layout + paint olması için birkaç frame bekle.
      await Future<void>.delayed(const Duration(milliseconds: 32));
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      entry.remove();
    }
  }
}
