import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native visual QA liderlik ve çark kanıtı üretir', () {
    final script = File('tool/native_visual_qa.sh').readAsStringSync();
    final nativeTest = File(
      'integration_test/native_visual_qa_test.dart',
    ).readAsStringSync();
    final designQa = File('tool/design_qa.sh').readAsStringSync();
    final workflow = File(
      '../.github/workflows/flutter_ci.yml',
    ).readAsStringSync();

    expect(script, contains('CAPTURE_SCREENSHOT'));
    expect(script, contains('native_leaderboard'));
    expect(script, contains('native_spin_wheel'));
    expect(nativeTest, contains('leaderboard-podium'));
    expect(nativeTest, contains('native_spin_wheel'));
    expect(designQa, contains('native_visual_qa.sh'));
    expect(workflow, contains('native-visual-qa:'));
    expect(workflow, contains('./tool/native_visual_qa.sh'));
  });
}
