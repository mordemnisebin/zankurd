import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('son kullanıcı soru fallback akışları oynanabilir listeyi kullanır', () {
    const paths = [
      'lib/src/screens/quiz/quiz_screen_ui.dart',
      'lib/src/screens/contest_screen.dart',
      'lib/src/screens/level_placement_screen.dart',
      'lib/src/screens/leaderboard_screen.dart',
      'lib/src/screens/matchmaking_screen.dart',
      'lib/src/screens/profile_screen.dart',
      'lib/src/screens/room_screen.dart',
      'lib/src/screens/tournament_screen.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('widget.repository.questions')),
        reason: '$path ham soru listesini son kullanıcı akışında kullanıyor',
      );
    }
  });
}
