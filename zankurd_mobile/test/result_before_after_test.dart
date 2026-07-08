import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  Future<void> capture(
    WidgetTester tester, {
    required String filename,
    required QuizResultScreen screen,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: screen,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/screenshots/phase2c/$filename');
      await file.create(recursive: true);
      await file.writeAsBytes(byteData!.buffer.asUint8List());
    });
  }

  testWidgets('Capture Quiz Result After Screen', (tester) async {
    final repository = MockZanKurdRepository();
    final room = repository.createRoom();

    await capture(
      tester,
      filename: 'result_after.png',
      screen: QuizResultScreen(
        repository: repository,
        room: room,
        score: 1840,
        correctCount: 8,
        wrongCount: 2,
        totalQuestions: 10,
        bestStreak: 5,
        coinsAwarded: 120,
        answerRecords: const [
          AnswerRecord(
            id: 'q1',
            category: 'Ziman',
            prompt: 'Ev gotin çi wateyê dide?',
            answers: ['A', 'B', 'C', 'D'],
            correctAnswer: 'A',
            selectedAnswer: 'A',
            explanation: 'Rast bersiv A ye.',
          ),
        ],
      ),
    );
  }, tags: ['preview']);
}