import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'realistic_device.dart';

Future<void> loadT15Fonts() async {
  await loadAppFonts();
  for (final family in {
    'Lucide': 'assets/fonts/Lucide.ttf',
    'FontAwesomeBrands': 'assets/fonts/Font-Awesome-7-Brands-Regular-400.otf',
  }.entries) {
    await (FontLoader(family.key)..addFont(
          File(family.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
        ))
        .load();
  }
}

/// Opt-in evidence only; ordinary CI does not create artifacts in the repo.
Future<void> captureT15(WidgetTester tester, String filename) async {
  final directory = Platform.environment['T15_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('t15-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$filename.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
