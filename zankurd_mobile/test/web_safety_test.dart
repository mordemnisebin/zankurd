import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home screen does not directly read dart:io environment', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(contains('Platform.environment')));
  });
}
