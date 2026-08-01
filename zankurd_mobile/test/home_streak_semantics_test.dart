import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ana sayfa seri rozeti yer tutucuyu gerçek gün sayısıyla doldurur', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();

    expect(source, contains('semanticLabel: context.t(K.dailyStreakDays, {'));
    expect(source, contains("'days': '\$_streak'"));
  });
}
