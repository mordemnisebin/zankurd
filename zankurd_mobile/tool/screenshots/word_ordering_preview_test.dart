// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Cümle kurma bileşeninin açık ve koyu temadaki gerçek görüntüsünü üretir.
///
/// 2026-07-25 denetiminde `.screenshots/` altındaki "canlı simülatör"
/// görüntülerinin tamamının aynı hata ekranı olduğu görüldü; bu script
/// bileşenin gerçekten nasıl göründüğünü doğrulanabilir biçimde basar.
///
/// ```bash
/// flutter test tool/screenshots/word_ordering_preview_test.dart
/// ```
const _question = QuizQuestion(
  id: 'wo-ku-007',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike',
  answers: ['Ez', 'ji', 'te', 'hez', 'dikim'],
  correctAnswer: 'Ez ji te hez dikim',
  explanation: '',
  type: QuestionType.wordOrdering,
);

/// Görünüm boyutunu ayarlar.
///
/// `setSurfaceSize` YALNIZCA render yüzeyini değiştirir; `MediaQuery.sizeOf`
/// hâlâ varsayılan 800x600'ü döner. Bu yüzden `MediaQuery` genişliğine göre
/// dallanan ekranlar (ör. profil `width > 720` ile iki sütuna geçer) test
/// görüntülerinde yanlış düzeni çizip taşma şeridi gösteriyordu. Doğrusu
/// `tester.view` üzerinden fiziksel boyutu vermek.
void _applyViewport(WidgetTester tester, Size size, {double dpr = 3.0}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}

Future<void> _capture(
  WidgetTester tester, {
  required ThemeMode mode,
  required String fileName,
}) async {
  _applyViewport(tester, const Size(390, 500));
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: AppTheme.bgOf(context),
            body: RepaintBoundary(
              key: boundaryKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: WordOrderingWidget(
                  key: const ValueKey('preview'),
                  question: _question,
                  disabled: false,
                  onAnswerSubmitted: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Havuzdan iki kelime seçilmiş bir ara durumu göster: hem cümle alanı hem
  // havuz aynı karede görünsün.
  await tester.tap(find.text('Ez'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ji'));
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/word_ordering/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    print('Yazıldı: ${file.absolute.path}');
  });
}

void main() {
  testWidgets('Cümle kurma — açık tema', (tester) async {
    await _capture(tester, mode: ThemeMode.light, fileName: 'light.png');
  }, tags: ['preview']);

  testWidgets('Cümle kurma — koyu tema', (tester) async {
    await _capture(tester, mode: ThemeMode.dark, fileName: 'dark.png');
  }, tags: ['preview']);
}
