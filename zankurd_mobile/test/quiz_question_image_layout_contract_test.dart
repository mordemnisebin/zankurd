import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('soru görseli ortak compact-landscape kuralını kullanır', () {
    final source = File(
      'lib/src/screens/quiz/quiz_widgets.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final isLandscapeTablet = _useCompactLandscapeLayout('),
    );
    expect(
      source,
      isNot(contains('size.width >= 700 && size.width > size.height')),
    );
  });
}
