// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Girdi alanının bütün durumları tek karede: dinlenme, odak, hata,
/// kapalı, arama, açılır liste ve ayarlardaki "Kaydet"in iki hâli.
///
/// ```bash
/// ZANKURD_FORM_STATES_OUT_DIR=.tmp/form_states \
///   flutter test tool/screenshots/form_states_preview_test.dart
/// ```
Future<void> _capture(WidgetTester tester, ThemeMode mode) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(390, 1100) * 2;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  final focus = FocusNode();
  addTearDown(focus.dispose);
  final formKey = GlobalKey<FormState>();
  final texts = List.generate(3, (_) => TextEditingController());
  for (final c in texts) {
    addTearDown(c.dispose);
  }
  texts[2].text = 'Rojda';

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return Scaffold(
            backgroundColor: t.bg,
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: t.bg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                      child: SahneSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SahneField(
                              label: 'Dinlenme',
                              controller: texts[0],
                              hintText: 'Yer tutucu',
                              prefixIcon: AppIcons.user,
                            ),
                            const SizedBox(height: 16),
                            SahneField(
                              label: 'Odakta',
                              controller: texts[1],
                              focusNode: focus,
                              hintText: 'Yer tutucu',
                              prefixIcon: AppIcons.user,
                            ),
                            const SizedBox(height: 16),
                            SahneField(
                              label: 'Hatalı',
                              controller: TextEditingController(),
                              hintText: 'Yer tutucu',
                              prefixIcon: AppIcons.user,
                              validator: (v) => 'Bu alan gerekli',
                            ),
                            const SizedBox(height: 16),
                            SahneField(
                              label: 'Kapalı',
                              controller: texts[2],
                              enabled: false,
                              prefixIcon: AppIcons.user,
                            ),
                            const SizedBox(height: 16),
                            SahneField.search(hintText: 'Ara…'),
                            const SizedBox(height: 16),
                            SahneDropdownField<String>(
                              label: 'Açılır liste',
                              hintText: 'Bir konu seç…',
                              items: const [
                                DropdownMenuItem(
                                  value: 'a',
                                  child: Text('Dil'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SahneButton.primary(
                              label: 'Kaydet (değişiklik var)',
                              arrow: false,
                              expand: true,
                              onPressed: () {},
                            ),
                            const SizedBox(height: 8),
                            const SahneButton.primary(
                              label: 'Kaydet (değişiklik yok)',
                              arrow: false,
                              expand: true,
                              onPressed: null,
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
        },
      ),
    ),
  );
  focus.requestFocus();
  formKey.currentState!.validate();
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['ZANKURD_FORM_STATES_OUT_DIR'] ??
        'docs/screenshots/form_states';
    final file = File('$dir/${mode.name}.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    print('Yazıldı: ${file.absolute.path}');
  });
}

void main() {
  testWidgets(
    'Girdi durumları — açık tema',
    (tester) => _capture(tester, ThemeMode.light),
    tags: ['preview'],
  );
  testWidgets(
    'Girdi durumları — koyu tema',
    (tester) => _capture(tester, ThemeMode.dark),
    tags: ['preview'],
  );
}
