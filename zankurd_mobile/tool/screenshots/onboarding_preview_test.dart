// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Tanıtım turunun iki slaytının gerçek görüntüsü.
///
/// Onboarding yalnız ilk açılışta gösterilir ve bayrağı kalıcıdır; temiz
/// kurulumda bile simülatörde tekrar tetiklemek güvenilir değil. Görsel
/// değişiklikleri doğrulamak için ekran doğrudan çizilir.
///
/// ```bash
/// flutter test tool/screenshots/onboarding_preview_test.dart
/// ```
void _applyViewport(WidgetTester tester, Size size, {double dpr = 3.0}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}

Future<void> _capture(
  WidgetTester tester, {
  required String lang,
  required int page,
  required String fileName,
}) async {
  SharedPreferences.setMockInitialValues({});
  _applyViewport(tester, const Size(390, 844));
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang(lang),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: RepaintBoundary(
          key: boundaryKey,
          child: OnboardingScreen(onComplete: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // İkinci slayta geçmek için ileri düğmesine bas.
  for (var i = 0; i < page; i++) {
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
  }

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/onboarding/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    print('Yazıldı: ${file.absolute.path}');
  });
}

void main() {
  testWidgets('Onboarding — 1. slayt (TR)', (tester) async {
    await _capture(tester, lang: 'tr', page: 0, fileName: 'tr_1.png');
  }, tags: ['preview']);

  testWidgets('Onboarding — 2. slayt (TR)', (tester) async {
    await _capture(tester, lang: 'tr', page: 1, fileName: 'tr_2.png');
  }, tags: ['preview']);
}
