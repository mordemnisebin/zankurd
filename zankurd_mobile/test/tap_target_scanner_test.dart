import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

ProcessResult _runScanner(String source) {
  final temp = Directory.systemTemp.createTempSync('zankurd-tap-target-');
  addTearDown(() => temp.deleteSync(recursive: true));
  final lib = Directory('${temp.path}/lib')..createSync();
  File('${lib.path}/fixture.dart').writeAsStringSync(source);

  return Process.runSync('python3', [
    'tool/a11y/tap_target_taramasi.py',
    '--kok',
    lib.path,
  ], workingDirectory: Directory.current.path);
}

void main() {
  test('sarmalayanı bilinmeyen küçük kısıt CI kapısını düşürür', () {
    final result = _runScanner('''
Widget build(BuildContext context) {
  return Container(
    constraints: const BoxConstraints(minWidth: 18),
  );
}
''');

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('BİLİNMİYOR'));
  });
}
