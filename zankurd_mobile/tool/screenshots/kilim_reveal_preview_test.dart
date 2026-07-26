// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_progress_bar.dart';
import 'package:zankurd_mobile/src/widgets/kilim_reveal.dart';

/// Kilim görsel dilinin gerçek görüntüsü.
///
/// Kutlama katmanını uygulamada görmek 10 soruluk bir turu oynayıp en az
/// yarısını doğru bilmeyi gerektiriyor; görsel bir öğeyi doğrulamak için
/// güvenilmez ve pahalı bir yol. Bu önizleme motifi ve kutlamayı doğrudan
/// çizer.
///
/// ```bash
/// flutter test tool/screenshots/kilim_reveal_preview_test.dart
/// ```
void _applyViewport(WidgetTester tester, Size size, {double dpr = 3.0}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}

Future<void> _capture(
  WidgetTester tester, {
  required ThemeMode mode,
  required String fileName,
  required bool reducedMotion,
}) async {
  _applyViewport(tester, const Size(375, 340));
  final boundaryKey = GlobalKey();

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
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kutlama katmanı — sonuç başlığının gerçek zemininde.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: KilimReveal(
                        active: true,
                        reducedMotion: reducedMotion,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.culturalBrandBg,
                                AppTheme.brandDeep,
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Pîroz be!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // İlerleme çubuğu motifi — marka zemini üzerinde.
                    const KilimProgressBar(value: 0.65, height: 10),
                    const SizedBox(height: 14),
                    // Renkli hero üzerindeki beyaz varyant.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.culturalBrandBg,
                      ),
                      child: KilimProgressBar(
                        value: 0.65,
                        height: 10,
                        color: Colors.white,
                        trackColor: Colors.white.withValues(alpha: 0.22),
                        borderColor: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Animasyonun ortasını değil, tamamlanmış hâlini yakala.
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/kilim/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    print('Yazıldı: ${file.absolute.path}');
  });
}

void main() {
  testWidgets('Kilim dili — açık tema', (tester) async {
    await _capture(
      tester,
      mode: ThemeMode.light,
      fileName: 'light.png',
      reducedMotion: false,
    );
  }, tags: ['preview']);

  testWidgets('Kilim dili — koyu tema', (tester) async {
    await _capture(
      tester,
      mode: ThemeMode.dark,
      fileName: 'dark.png',
      reducedMotion: false,
    );
  }, tags: ['preview']);

  testWidgets('Kilim dili — hareket azaltılmış', (tester) async {
    await _capture(
      tester,
      mode: ThemeMode.light,
      fileName: 'reduced_motion.png',
      reducedMotion: true,
    );
  }, tags: ['preview']);
}
