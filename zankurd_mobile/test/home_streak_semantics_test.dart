import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ana sayfa seri çipi yer tutucuyu gerçek gün sayısıyla doldurur', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();

    // Seri çipi artık "Bugün" panelinde (DailyMissionsCard).
    expect(
      source,
      contains('streakSemanticLabel: context.t(K.dailyStreakDays, {'),
    );
    expect(source, contains("'days': '\$_streak'"));
  });
}
