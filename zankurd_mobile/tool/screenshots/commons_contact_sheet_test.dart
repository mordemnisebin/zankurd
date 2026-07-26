// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Commons adaylarının kontak baskısı.
///
/// Gerçek fotoğraf seçimi gözle yapılmak zorunda: otomatik sıralama
/// "Gola Wanê" için Fransa'daki bir gölü, "erbane" için Bella Coola
/// yerlilerini ilk sıraya koydu (2026-07-26). Yanlış fotoğraf,
/// fotoğrafsızlıktan kötüdür.
///
/// Bu test `harvest_commons_candidates.py`nin indirdiği önizlemeleri
/// kavram kavram, numaralı olarak tek karede dizer; seçim o kareye
/// bakılarak yapılır.
///
/// ```bash
/// python3 tool/harvest_commons_candidates.py
/// flutter test tool/screenshots/commons_contact_sheet_test.dart
/// ```
void main() {
  testWidgets('aday kontak baskıları', (tester) async {
    final manifest =
        jsonDecode(File('/tmp/zk_commons/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final slugs = manifest.keys.toList()..sort();

    const perSheet = 7;
    for (var sheet = 0; sheet * perSheet < slugs.length; sheet++) {
      final chunk = slugs.skip(sheet * perSheet).take(perSheet).toList();

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(1180, 168.0 * chunk.length + 16);
      addTearDown(tester.view.reset);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            color: const Color(0xFFF5F2EC),
            child: RepaintBoundary(
              key: boundaryKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final slug in chunk)
                    SizedBox(
                      height: 168,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                slug,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          for (
                            var i = 0;
                            i < (manifest[slug] as List).length;
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$i',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 220,
                                    height: 132,
                                    child: Image.file(
                                      File(
                                        (manifest[slug] as List)[i]['thumb']
                                            as String,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: Color(0xFFDDDDDD),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('/tmp/zk_commons/sheet-$sheet.png');
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        print('yazıldı: ${file.path} (${chunk.join(", ")})');
      });
    }
  });
}
