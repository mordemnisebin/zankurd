import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kurmanci room and tournament labels use one native glossary', () {
    final friends = File(
      'lib/src/screens/friends_screen.dart',
    ).readAsStringSync();
    final shell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    final onboarding = File(
      'lib/src/screens/onboarding_screen.dart',
    ).readAsStringSync();
    final playHub = File(
      'lib/src/screens/play_hub_screen.dart',
    ).readAsStringSync();
    final tournament = File(
      'lib/src/screens/tournament_screen.dart',
    ).readAsStringSync();

    expect(friends, contains("context.isKu ? 'Jûr nehat avakirin'"));
    expect(friends, contains("ku ? 'Serhêl' : 'Çevrimiçi'"));
    expect(friends, contains("ku ? 'Ne li serhêl' : 'Çevrimdışı'"));
    expect(shell, isNot(contains('hevalên te, Turnuva')));
    expect(onboarding, isNot(contains("ku ? 'Turnuva")));
    expect(playHub, contains("ku ? 'Kûpa' : 'Turnuva Modu'"));
    expect(tournament, isNot(contains("ku ? 'Turnuva")));
    expect(tournament, isNot(contains("? 'Turnuvaya")));
  });
}
