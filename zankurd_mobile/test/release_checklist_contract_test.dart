import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beta release checklist covers the complete user journey', () {
    final checklist = File('../docs/release-readiness.md').readAsStringSync();

    for (final gate in [
      'Android',
      'iOS',
      '1v1',
      'oda kurma',
      'bildirim',
      'hesap silme',
      'Beta geri bildirimi',
      'kozmetik',
    ]) {
      expect(checklist.toLowerCase(), contains(gate.toLowerCase()));
    }
  });

  test('README links to the checked-in release checklist', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('../docs/release-readiness.md'));
    expect(File('../docs/release-readiness.md').existsSync(), isTrue);
  });

  test('mobile release guide matches the enforced configuration gate', () {
    final guide = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();

    expect(guide, contains('--dart-define-from-file=.env.mobile.release.json'));
    expect(
      guide,
      contains('RevenueCat anahtarları release derlemesinde zorunludur'),
    );
    expect(
      guide,
      isNot(contains('RevenueCat anahtarları verilmezse premium **mock modda** kalır')),
    );
  });
}
