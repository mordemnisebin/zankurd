import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tek komutluk Design QA native Patrol kapısını sunar', () {
    final script = File('tool/design_qa.sh').readAsStringSync();

    expect(script, contains('--native'));
    expect(script, contains('patrol test'));
    expect(script, contains('tap_target_taramasi.py'));
  });

  test('Patrol smoke gerçek ZanKurd uygulama ağacını açar', () {
    final smoke = File('patrol_test/smoke_test.dart').readAsStringSync();

    expect(smoke, contains("package:zankurd_mobile/main.dart"));
    expect(smoke, contains('ZanKurdApp('));
    expect(smoke, contains('AppShell('));
  });

  test('CI macOS üzerinde Patrol smoke çalıştırır', () {
    final workflow = File(
      '../.github/workflows/flutter_ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('patrol-ios-smoke:'));
    expect(workflow, contains('patrol test'));
  });
}
