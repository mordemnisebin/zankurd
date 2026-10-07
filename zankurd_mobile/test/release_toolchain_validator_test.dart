import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_release_toolchain.dart';

void main() {
  test('release toolchain accepts the pinned Flutter framework version', () {
    expect(releaseToolchainProblem('3.44.7'), isNull);
  });

  test('release toolchain rejects a different Flutter framework version', () {
    final problem = releaseToolchainProblem('3.47.2');

    expect(problem, isNotNull);
    expect(problem, contains('3.44.7'));
    expect(problem, contains('3.47.2'));
  });

  test('release guide and CI use the same pinned Flutter guard', () {
    final guide = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    final ci = File('../.github/workflows/flutter_ci.yml').readAsStringSync();

    expect(guide, contains('dart run tool/validate_release_toolchain.dart'));
    expect(ci, contains('dart run tool/validate_release_toolchain.dart'));
    expect(ci, contains("flutter-version: '$requiredFlutterFrameworkVersion'"));
  });
}
