// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

void main() {
  testWidgets('Capture Quiz Before Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    
    final repository = MockZanKurdRepository();
    final room = repository.createRoom();
    final questions = repository.questions.take(3).toList();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: QuizScreen(
                repository: repository,
                room: room,
                questions: questions,
                enableTimer: false,
              ),
            ),
          ),
        ),
      ),
    );

    // Animasyon ve sayfa yerleşiminin oturmasını bekleyelim
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/quiz_before.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('Quiz BEFORE screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);

  testWidgets('Capture Quiz After Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    
    final repository = MockZanKurdRepository();
    final room = repository.createRoom();
    final questions = repository.questions.take(3).toList();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: QuizScreen(
                repository: repository,
                room: room,
                questions: questions,
                enableTimer: false,
              ),
            ),
          ),
        ),
      ),
    );

    // Animasyon ve sayfa yerleşiminin oturmasını bekleyelim
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File('docs/screenshots/phase2b/quiz_after.png');
      await file.create(recursive: true);
      await file.writeAsBytes(pngBytes);
      print('Quiz AFTER screenshot generated at: ${file.absolute.path}');
    });
  }, tags: ['preview']);
}
