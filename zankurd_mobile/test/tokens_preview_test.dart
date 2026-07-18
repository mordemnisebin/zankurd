// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/dev/design_tokens_preview_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  test('mockup brand token contract stays stable', () {
    expect(AppRadius.card, 14);
    expect(AppTheme.brandGreen, const Color(0xFF3DA968));
    expect(AppTheme.brandGreenDeep, const Color(0xFF2A7A4E));
    expect(AppTheme.playGreen, const Color(0xFF3DA968));
    expect(AppTheme.gold, const Color(0xFFE7B53C));
    expect(AppTheme.bg, const Color(0xFF0B0F0D));
    expect(AppTheme.surface, const Color(0xFF1E3028));
    expect(AppTheme.lightBg, const Color(0xFFFBF9F6));
  });

  test('legacy token aliases resolve to theme tokens', () {
    expect(AppTheme.primaryGradientStart, AppTheme.brandGreen);
    expect(AppTheme.primaryGradientEnd, AppTheme.brandGreenDeep);
    expect(AppTheme.accent, AppTheme.primaryGradientStart);
    expect(AppTheme.cyan, AppTheme.playCyan);
    expect(AppTheme.violet, AppTheme.secondaryAccent);
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
