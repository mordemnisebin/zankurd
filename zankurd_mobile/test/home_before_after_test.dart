// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/home/hero_card.dart';

void main() {
  testWidgets('Capture Home After Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    
    final repository = MockZanKurdRepository();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider.test()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: HomeScreen(
                repository: repository,
                displayName: 'Zelal Test',
                scrollController: ScrollController(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/home_after.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('Home AFTER screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);

  testWidgets('Capture Hero Card Pattern Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 380));
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: RepaintBoundary(
              key: boundaryKey,
              child: HeroCard(
                isKu: false,
                loading: false,
                onCreateRoom: () {},
                onJoinRoom: () {},
                onQuickMatch: () {},
                drawPattern: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/hero_pattern.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('Hero Pattern screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);

  testWidgets('Capture Hero Card No Pattern Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 380));
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: RepaintBoundary(
              key: boundaryKey,
              child: HeroCard(
                isKu: false,
                loading: false,
                onCreateRoom: () {},
                onJoinRoom: () {},
                onQuickMatch: () {},
                drawPattern: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/hero_no_pattern.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('Hero No Pattern screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);
}
