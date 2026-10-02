import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ARCHITECTURE “cam paneli yok” diyor; `CardType.glass` API’si durunca
/// yeni ekranlar sessizce geri kayıyordu.
void main() {
  test('CardType.glass ve glassDecoration üretim kodunda yok', () {
    final theme = File('lib/src/theme/app_theme.dart').readAsStringSync();
    final panel = File('lib/src/widgets/app_panel.dart').readAsStringSync();

    expect(theme, isNot(contains('glass,')));
    expect(theme, isNot(contains('glassDecoration')));
    expect(panel, isNot(contains('CardType.glass')));
    expect(panel, isNot(contains('BackdropFilter')));
  });
}
