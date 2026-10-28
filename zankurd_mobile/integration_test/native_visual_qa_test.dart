import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/word_drill_screen.dart';
import 'package:zankurd_mobile/src/widgets/app_state.dart';

class _FailFirstQuestionRandom implements math.Random {
  final math.Random _delegate = math.Random(3);
  bool fail = true;

  @override
  int nextInt(int max) {
    if (fail) {
      fail = false;
      throw StateError('test-only question generation failure');
    }
    return _delegate.nextInt(max);
  }

  @override
  bool nextBool() => _delegate.nextBool();

  @override
  double nextDouble() => _delegate.nextDouble();
}

class _NativeVisualRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => const [
    LeaderboardEntry(
      rank: 1,
      playerId: 'native-1',
      displayName: 'Rojda',
      totalScore: 8420,
      bestStreak: 11,
      roomsPlayed: 14,
    ),
    LeaderboardEntry(
      rank: 2,
      playerId: 'native-2',
      displayName: 'Baran',
      totalScore: 7190,
      bestStreak: 9,
      roomsPlayed: 12,
    ),
    LeaderboardEntry(
      rank: 3,
      playerId: 'native-3',
      displayName: 'Dilan',
      totalScore: 6540,
      bestStreak: 8,
      roomsPlayed: 10,
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.lang': 'ku',
    });
  });

  Future<void> capture(String name) async {
    // ignore: avoid_print
    print('CAPTURE_SCREENSHOT: $name');
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  testWidgets('native görsel yüzeyler simülatörde çizilir', (tester) async {
    final repository = _NativeVisualRepository();
    final auth = AuthProvider.test(authenticated: true);

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: auth,
        home: LeaderboardScreen(repository: repository),
      ),
    );
    await tester.pump();
    // Veri yüklenip liste çizilsin; kanıt görüntüsü son hâli göstermeli.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 100));
    // 2026-09-29 doğallık (K9): podyum kalktı; ilk üç de sıra satırıdır.
    // 2026-10-02 (A8): podyum geri geldi. Üç oyuncuda yalnız podyum çizilir
    // (`leaderboard-rank-list` yok), dörtte ve üstünde podyum + liste; ilk
    // üçün satır anahtarları iki yüzeyde de aynıdır. Bu test yalnız
    // "sıralama yüzeyi çizildi" der, hangisinin çizildiğine bağlı değildir.
    expect(
      find.byKey(const ValueKey('leaderboard-podium')).evaluate().length +
          find.byKey(const ValueKey('leaderboard-rank-list')).evaluate().length,
      greaterThanOrEqualTo(1),
    );
    expect(
      find.byKey(const ValueKey('leaderboard-rank-row-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('leaderboard-rank-row-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('leaderboard-rank-row-3')),
      findsOneWidget,
    );
    expect(find.byType(LeaderboardScreen), findsOneWidget);
    await capture('native_leaderboard');

    // ZanKurdApp `MaterialApp`ın Navigator anahtarını kökte paylaşır; başka
    // bir ekran örneğine geçerken test ağacını sökmeden pumpWidget aynı rotayı
    // bırakabilir. İkinci native görüntü önceki ekranın aynısı çıkmıştı.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: auth,
        home: SpinWheelScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SpinWheelScreen), findsOneWidget);
    await capture('native_spin_wheel');
  });

  testWidgets(
    'native öğrenme ve kelime tekrarı hata/yeniden deneme yüzeyleri',
    (tester) async {
      final repository = _NativeVisualRepository();
      final auth = AuthProvider.test(authenticated: true);
      await tester.pumpWidget(
        ZanKurdApp(
          repository: repository,
          authProvider: auth,
          home: LearningScreen(repository: repository),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LearningScreen), findsOneWidget);
      await capture('native_learning');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      WordListStore.resetInstance();
      final store = await WordListStore.load(storage: InMemoryDataStorage());
      await store.add(
        'rojbas',
        now: DateTime.now().subtract(const Duration(days: 1)),
      );
      await tester.pumpWidget(
        ZanKurdApp(
          repository: repository,
          authProvider: auth,
          home: WordDrillScreen(
            store: store,
            random: _FailFirstQuestionRandom(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final error = find.byKey(const ValueKey('word-review-load-error'));
      expect(error, findsOneWidget);
      await capture('native_word_review_error');

      tester.widget<AppErrorState>(error).onRetry();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('word-review-prompt')), findsOneWidget);
      await capture('native_word_review_retry');
    },
  );
}
