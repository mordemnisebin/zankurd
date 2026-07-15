import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical matchmaking and mission catches report errors', () {
    final sources = [
      File('lib/src/screens/matchmaking_screen.dart').readAsStringSync(),
      File('lib/src/data/daily_mission_store.dart').readAsStringSync(),
      File('lib/src/data/supabase_zankurd_repository.dart').readAsStringSync(),
    ];

    for (final source in sources) {
      expect(source, contains('ErrorReporter.record'));
      expect(source, contains('catch (error, stack)'));
    }

    expect(
      sources.last,
      isNot(contains('catch (_)')),
    );
  });
}
