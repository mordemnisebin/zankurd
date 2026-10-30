// T8 çevrimdışı görsel bekçisi; üretim main bağlantısı yok.
// flutter run -d web-server --target tool/t8_web_preview.dart --web-port 8178
// ?screen=forfeit|final|inbox|auth|settings|learning|matchmaking&lang=tr|ku&scale=1.3
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import '../test/support/t8_visual_fixtures.dart';

/// Web ve native görsel girişlerin paylaştığı çevrimdışı ekran seçimi.
Widget t8PreviewScreen(Map<String, String> query, T8VisualRepo repo) =>
    switch (query['screen']) {
      'auth' => ProfileScreen(repository: repo),
      'settings' => SettingsScreen(
        repository: repo,
        packageInfoLoader: () async => PackageInfo(
          appName: 'ZanKurd',
          packageName: 't8.preview',
          version: 'T8',
          buildNumber: '8',
        ),
      ),
      'learning' => LearningScreen(repository: repo),
      'matchmaking' => MatchmakingScreen(repository: repo),
      'inbox' => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AsyncDuelInboxSection(repository: T8DuelRepo(true)),
          ),
        ),
      ),
      _ => TournamentScreen(
        repository: T8CupRepo(
          t8TournamentBracket(
            t8TournamentMatch(submitted: query['screen'] != 'forfeit'),
          ),
        ),
      ),
    };

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  final query = Uri.base.queryParameters;
  final repo = T8VisualRepo();
  final auth = T8VisualAuthProvider();
  auth.presence.bind(T8PresenceGateway(), userId: 't8-guest');
  auth.presence.didChangeAppLifecycleState(AppLifecycleState.resumed);
  final child = t8PreviewScreen(query, repo);
  runApp(
    ZanKurdApp(
      repository: repo,
      authProvider: auth,
      languageProvider: LanguageProvider(initialLang: query['lang'] ?? 'tr'),
      themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
      home: Builder(
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            platform: query['platform'] == 'ios'
                ? TargetPlatform.iOS
                : Theme.of(context).platform,
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                double.tryParse(query['scale'] ?? '') ?? 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
