// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/dev/design_tokens_preview_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  test('Pirs-inspired brand token contract stays stable', () {
    expect(AppRadius.card, 16);
    expect(AppTheme.brandOrange, const Color(0xFFF47A32));
    expect(AppTheme.playGreen, const Color(0xFF58B96B));
    expect(AppTheme.playPink, const Color(0xFFE72F8C));
    expect(AppTheme.playCyan, const Color(0xFF3BC7C1));
    expect(AppTheme.playPurple, const Color(0xFF8A62D3));
    expect(AppTheme.lightBg, const Color(0xFFF4F5F7));
  });

  test('legacy token aliases resolve to Pirs-inspired tokens', () {
    expect(AppTheme.primaryGradientStart, AppTheme.brandOrange);
    expect(AppTheme.primaryGradientEnd, AppTheme.brandOrangeWarm);
    expect(AppTheme.accent, AppTheme.playPink);
    expect(AppTheme.cyan, AppTheme.playCyan);
    expect(AppTheme.violet, AppTheme.playPurple);
  });

  testWidgets('Generate design tokens preview image', (
    WidgetTester tester,
  ) async {
    // 390x844 (modern mobil cihaz boyutu) ayarla
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKey,
          child: const DesignTokensPreviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // toImage asenkron piksellendirme yaptığı için tester.runAsync içinde çalıştırılmalıdır.
    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // toImage çağrısını asenkron olarak bekleyelim
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/design_tokens_preview.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);

      print('PNG successfully generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);
}
