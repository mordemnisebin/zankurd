import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('Capture Profile After Screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final repository = MockZanKurdRepository();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider.test()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: ProfileScreen(
                repository: repository,
                scrollController: ScrollController(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/screenshots/phase2c/profile_after.png');
      await file.create(recursive: true);
      await file.writeAsBytes(byteData!.buffer.asUint8List());
    });
  }, tags: ['preview']);
}