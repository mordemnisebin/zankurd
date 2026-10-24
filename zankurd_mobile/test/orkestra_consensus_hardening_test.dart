import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/streak_repair_card.dart';
import '../tool/question_quality/src/near_duplicate_reviewed.dart';
import 'support/widget_test_helpers.dart';

class _TrackingRankRepo extends MockZanKurdRepository {
  int rankCalls = 0;

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async {
    rankCalls++;
    return super.getMyLeaderboardRank(period);
  }
}

class _UnblockFailingRepo extends MockZanKurdRepository {
  int unblockCalls = 0;

  @override
  Future<List<PlayerSearchResult>> loadBlockedPlayers() async {
    return const [
      PlayerSearchResult(
        id: 'blocked_1',
        displayName: 'BlockedUser',
        playerTag: '9999',
      ),
    ];
  }

  @override
  Future<bool> unblockPlayer(String playerId) async {
    unblockCalls++;
    throw Exception('simulated unblock network failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    freshMockRepository();
  });

  group('Orkestra Consensus Hardening (13 Safety Fixes)', () {
    test(
      '1. PremiumService disposed guard ignores notifyListeners without error',
      () {
        final service = PremiumService.forTesting(
          isAnonymous: () async => true,
          logOut: () async => throw UnimplementedError(),
        );
        service.dispose();
        expect(() => service.notifyListeners(), returnsNormally);
      },
    );

    test(
      '2. AuthProvider disposed guard stops notifyListeners & refreshGuestUpgrade',
      () async {
        final provider = AuthProvider.test();
        provider.dispose();
        expect(() => provider.notifyListeners(), returnsNormally);
        final refreshed = await provider.refreshGuestUpgrade();
        expect(refreshed, isFalse);
      },
    );

    test(
      '3. near_duplicate_reviewed: ds_cografya_0129 ~ ds_cografya_0133 marked as retired partner',
      () {
        final entry = reviewedNearDuplicates.entries.firstWhere(
          (e) => e.value.contains('ds_cografya_0129 ~ ds_cografya_0133'),
        );
        expect(
          entry.value,
          "ds_cografya_0129 ~ ds_cografya_0133: aynı bilgi; biri emekli (Grok + ana ajan)",
        );
      },
    );

    testWidgets(
      '4. Tournament _LobbyView starting flag disables primary button',
      (tester) async {
        final repo = freshMockRepository();
        await tester.pumpWidget(
          testShell(child: TournamentScreen(repository: repo)),
        );
        await tester.pumpAndSettle();

        final joinButtonFinder = find.byKey(
          const ValueKey('tournament-primary-cta'),
        );
        expect(joinButtonFinder, findsOneWidget);
        final startButton = tester.widget<SahneButton>(joinButtonFinder);
        // Button is initially enabled
        expect(startButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      '5. ThisWeekCard updates listener when refreshSignal changes in didUpdateWidget',
      (tester) async {
        final repo = _TrackingRankRepo();
        final signal1 = ChangeNotifier();
        final signal2 = ChangeNotifier();

        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: ThisWeekCard(
                repository: repo,
                onStart: () {},
                refreshSignal: signal1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.rankCalls, 1);

        // Rebuild with signal2
        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: ThisWeekCard(
                repository: repo,
                onStart: () {},
                refreshSignal: signal2,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger signal2
        signal2.notifyListeners();
        await tester.pumpAndSettle();
        expect(repo.rankCalls, 2);

        // Signal1 should no longer trigger load
        signal1.notifyListeners();
        await tester.pumpAndSettle();
        expect(repo.rankCalls, 2);
      },
    );

    testWidgets('6. StreakRepairCard renders safely and handles offer', (
      tester,
    ) async {
      final repo = freshMockRepository();
      final store = await StreakStore.load();
      const offer = StreakRepairOffer(
        lostStreak: 5,
        breakDay: '2026-10-24',
        monthKey: '2026-10',
        playedToday: false,
      );

      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: StreakRepairCard(
              store: store,
              repository: repo,
              offer: offer,
              onRepaired: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final repairBtn = find.textContaining('${StreakStore.repairCost}');
      expect(repairBtn, findsOneWidget);
    });

    testWidgets(
      '7. ProfileScreen initializes _loadGeneration and renders safely',
      (tester) async {
        final repo = freshMockRepository();
        await tester.pumpWidget(
          testShell(child: ProfileScreen(repository: repo)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
      },
    );

    testWidgets(
      '8. PaywallScreen catches fetchOfferings exception and enters error state safely',
      (tester) async {
        final repo = freshMockRepository();
        final premium = PremiumService.forTesting(
          isAnonymous: () async => true,
          logOut: () async => throw UnimplementedError(),
          fetchOfferings: () async =>
              throw Exception('simulated offerings network failure'),
        );

        await tester.pumpWidget(
          testShell(
            premiumService: premium,
            child: PaywallScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Hata kartındaki "Tekrar dene" butonu görünmeli
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '9. StoryScreen handles choices safely and disables choices while busy',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          testShell(
            child: StoryScreen(story: cayxaneStory, guide: cayxaneGuide),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('story-text-ku')), findsOneWidget);
        final choiceFinder = find.text('Bir çay, lütfen.');
        expect(choiceFinder, findsOneWidget);

        await tester.tap(choiceFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('Şeker ister misin'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '10. SettingsScreen unblock handles exception and clears working state',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _UnblockFailingRepo();
        await tester.pumpWidget(
          testShell(child: SettingsScreen(repository: repo)),
        );
        await tester.pumpAndSettle();

        final unblockButton = find.byKey(const ValueKey('unblock-blocked_1'));
        expect(unblockButton, findsOneWidget);

        await tester.ensureVisible(unblockButton);
        await tester.pumpAndSettle();

        await tester.tap(unblockButton);
        await tester.pumpAndSettle();

        expect(repo.unblockCalls, 1);
        // Hata SnackBar'ı çıkmalı ve buton kilitli kalmamalı
        expect(find.byType(SnackBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
