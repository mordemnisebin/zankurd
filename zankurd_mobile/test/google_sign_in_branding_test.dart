import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google girişi uydurma metin G yerine marka glifini kullanır', () {
    final source = File(
      'lib/src/screens/sign_in_screen.dart',
    ).readAsStringSync();

    expect(source, contains('FontAwesomeIcons.google'));
    expect(source, isNot(contains("Text(\n                      'G'")));
  });

  test('misafir hesap bağlama da uydurma G harfi kullanmaz', () {
    final source = File(
      'lib/src/screens/profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('FontAwesomeIcons.google'));
    expect(
      source,
      isNot(contains("icon: const Text(\n                        'G'")),
    );
  });
}
