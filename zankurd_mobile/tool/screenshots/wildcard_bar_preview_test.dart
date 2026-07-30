// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Joker çubuğunun 375px genişlikte gerçek görüntüsü.
///
/// 2026-07-25 canlı denetimi: dört joker tek satırda "ad · fiyat" biçiminde
/// sıkıştırılıp `FittedBox` ile küçültülüyor, etiketler ~8pt'ye düşüyordu.
///
/// ```bash
/// flutter test tool/screenshots/wildcard_bar_preview_test.dart
/// ```
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
  _applyViewport(tester, const Size(375, 160));
  final boundaryKey = GlobalKey();

  const jokers = [
    WildcardType.fiftyFifty,
    WildcardType.audience,
    WildcardType.doubleAnswer,
    WildcardType.changeQuestion,
  ];

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppTheme.bgOf(context),
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    for (var i = 0; i < jokers.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: WildcardButton(
                          type: jokers[i],
                          isKu: true,
                          isEnabled: true,
                          isUsed: false,
                          isAnswered: false,
                          isActive: false,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/wildcard_bar/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    print('Yazıldı: ${file.absolute.path}');
  });
}

void main() {
  testWidgets('Joker çubuğu — açık tema', (tester) async {
    await _capture(tester, mode: ThemeMode.light, fileName: 'light.png');
  }, tags: ['preview']);

  testWidgets('Joker çubuğu — koyu tema', (tester) async {
    await _capture(tester, mode: ThemeMode.dark, fileName: 'dark.png');
  }, tags: ['preview']);
}
