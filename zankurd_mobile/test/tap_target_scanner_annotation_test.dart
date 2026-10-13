import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('açık noninteractive işareti küçük dekoratif kısıtı ayıklar', () {
    final temp = Directory.systemTemp.createTempSync('zankurd-tap-safe-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final lib = Directory('${temp.path}/lib')..createSync();
    File('${lib.path}/fixture.dart').writeAsStringSync('''
Widget build(BuildContext context) {
  return Container(
    // a11y-tap-target: noninteractive
    constraints: const BoxConstraints(minWidth: 18),
  );
}
''');

    final result = Process.runSync('python3', [
      'tool/a11y/tap_target_taramasi.py',
      '--kok',
      lib.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('NON-INTERACTIVE'));
  });
}
