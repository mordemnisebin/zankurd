import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.lang': 'ku',
    });
    await QuestionBankLoader.instance.load();
  });

  Future<void> markScreen(String name) async {
    // ignore: avoid_print
    print('CAPTURE_SCREENSHOT: $name');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  testWidgets('Simülatör Canlı Tur: Tüm ekranları gez ve görsel doğrula', (tester) async {
    final repo = MockZanKurdRepository();
    final auth = AuthProvider.test(authenticated: true);

    // 1. Ana Kabuk (AppShell) - Öğren Sekmesi (LearnHomeScreen)
    await tester.pumpWidget(ZanKurdApp(repository: repo, authProvider: auth));
    await tester.pumpAndSettle();
    await markScreen('01_learn_home');

    // 2. Yarış Sekmesi (PlayHubScreen)
    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();
    await markScreen('02_play_hub');

    // 3. Liderlik Sekmesi (LeaderboardScreen)
    await tester.tap(find.byKey(const ValueKey('nav-leaderboard')));
    await tester.pumpAndSettle();
    await markScreen('03_leaderboard');

    // 4. Arkadaşlar Ekranı (FriendsScreen)
    // Davet/100 coin kartı RPC basılana kadar gizli (`kReferralRewardsEnabled`).
    await tester.tap(find.byKey(const ValueKey('leaderboard-friends-button')));
    await tester.pumpAndSettle();
    await markScreen('04_friends');

    await tester.tap(find.byType(ZkBackButton));
    await tester.pumpAndSettle();

    // 6. Profil Sekmesi (ProfileScreen)
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await markScreen('06_profile');

    // 7. Ayarlar Ekranı (SettingsScreen)
    await tester.scrollUntilVisible(find.byIcon(AppIcons.gear), 100);
    await tester.tap(find.byIcon(AppIcons.gear));
    await tester.pumpAndSettle();
    await markScreen('07_settings');
  });

  testWidgets('Simülatör Soru Çözme Ekranı', (tester) async {
    final repo = MockZanKurdRepository();
    final auth = AuthProvider.test(authenticated: true);
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repo,
        authProvider: auth,
        home: LevelPlacementScreen(repository: repo, questionCount: 5),
      ),
    );
    await tester.pumpAndSettle();
    await markScreen('08_question_screen');
  });
}
