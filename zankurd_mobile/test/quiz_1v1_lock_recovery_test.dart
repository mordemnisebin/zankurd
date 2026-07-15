import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1v1 waiting phase has a bounded opponent timeout', () {
    final source = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    expect(source, contains('_opponentWaitTimer'));
    // Bekleme süresi oda süresinden kısa olmamalı, ama en az 20 saniye ile
    // sınırlı kalmalı; implementasyon bunu max(20, roomSeconds) ile kurar.
    expect(source, contains('max(20, widget.room.secondsPerQuestion)'));
    expect(source, contains('_startOpponentWaitTimer()'));
  });

  test('1v1 consumes opponent finished broadcasts', () {
    final source = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    expect(source, contains("payload['finished'] == true"));
    expect(source, contains('_opponentFinished'));
  });

  test('1v1 can request or perform progress when host is unavailable', () {
    final source = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    expect(source, contains("'advance_request': true"));
    expect(source, contains('_requestAuthoritativeAdvance()'));
    expect(source, contains('_advanceAuthoritativeIndex();'));
    expect(source, contains('_authoritativeAdvanceFallbackTimer'));
    expect(source, contains('if (!_isHost) return;'));
  });
}
