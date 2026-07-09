// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/quick_play_grid.dart';

void main() {
  testWidgets('Capture QuickPlay Before Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 260));

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RepaintBoundary(
                key: boundaryKey,
                child: QuickPlayGrid(
                  isKu: false,
                  dailyQuizLoading: false,
                  onDuel: () {},
                  onDailyQuiz: () {},
                  onSpinWheel: () {},
                  onTournament: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Animasyonların tamamlanması için bekleyelim
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/quickplay_before.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('QuickPlay BEFORE screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);

  testWidgets('Capture QuickPlay After Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 260));

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RepaintBoundary(
                key: boundaryKey,
                child: QuickPlayGrid(
                  isKu: false,
                  dailyQuizLoading: false,
                  onDuel: () {},
                  onDailyQuiz: () {},
                  onSpinWheel: () {},
                  onTournament: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Animasyonların tamamlanması için bekleyelim
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/quickplay_after.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('QuickPlay AFTER screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);
}
